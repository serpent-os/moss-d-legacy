/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client
 *
 * Client API for moss
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.client.impl;

import core.thread.osthread;
import core.time;
import moss.client.activeplugin;
import moss.client.cobbleplugin;
import moss.client.installation;
import moss.client.installdb;
import moss.client.label : Label;
import moss.client.layoutdb;
import moss.client.progressbar : ProgressBar, ProgressBarType;
import moss.client.remoteplugin;
import moss.client.remotes;
import moss.client.renderer : Renderer;
import moss.client.statedb;
import moss.client.systemcache;
import moss.client.systemroot;
import moss.client.ui;
import moss.config.io.configuration;
import moss.config.repo;
import moss.deps.registry;
import moss.fetcher.controller;
import moss.format.binary.payload.meta;
import moss.format.binary.reader : Reader;
import std.exception : enforce;
import std.experimental.logger;
import std.file : exists, mkdirRecurse;
import std.path : baseName, dirName, buildPath;
import std.range : empty;
import std.stdio : File, writeln;
import std.string : endsWith, format, join, toStringz;
import std.conv : to;
import core.sys.posix.fcntl : AT_FDCWD;

private static const uint renameExchange = (1 << 1);

/**
 * The only part of renameat2 we really want is `RENAME_EXCHANGE`
 */
extern (C) int renameat2(int olddirfd, const char* oldpath, int newdirfd,
        const char* newpath, uint flags);

/**
 * To throttle updates we only redraw the renderer on
 * a dedicated thread, allowing minimised and grouped
 * updates
 */
package class UIThread : Thread
{

    @disable this();

    this(Renderer ren) @trusted
    {
        super(&run);
        this.renderer = ren;
        this.isDaemon = true;
    }

    void stop() @trusted
    {
        running = false;
        join();
    }

private:

    void run() @trusted
    {
        running = true;
        while (running)
        {
            synchronized (renderer)
            {
                renderer.draw();
            }
            sleep(dur!"msecs"(1000 / 25));
        }
    }

    Renderer renderer;
    __gshared bool running;
}

/**
 * Provides high-level access to the moss system
 */
public final class MossClient
{
    /**
     * Initialise a MossClient with the given root dir
     */
    this(in string root = "/") @safe
    {
        /* Essentials */
        fc = new FetchController(4);
        _ui = new UserInterface();
        _installation = new Installation(root);
        _installation.ensureDirectories();
        _registry = new RegistryManager();

        /* Install DB */
        installDB = new InstallDB(_installation);
        installDB.connect.match!((Failure f) => fatalf(f.message), (_) {});

        /* System Cache */
        _cache = new SystemCache(_installation);
        _cache.connect.match!((Failure f) => fatalf(f.message), (_) {});

        /* Remote management */
        remoteManager = new RemoteManager(_registry, fc, _installation);

        /* StateDB */
        stateDB = new StateDB(_installation);
        stateDB.connect.match!((Failure f) => fatalf(f.message), (_) {});

        /* Layout DB */
        layoutDB = new LayoutDB(_installation);
        layoutDB.connect.match!((Failure f) => fatalf(f.message), (_) {});

        /* Actively installed */
        auto active = new ActivePlugin(_installation, installDB, stateDB);
        _registry.addPlugin(active);

        /* Cobble stones */
        cobble = new CobblePlugin(_installation);
        _registry.addPlugin(cobble);

        /* Progress bar management */
        foreach (i; 0 .. 4)
        {
            fetchProgress ~= new ProgressBar();
        }
        cacheProgress = new ProgressBar();
        cacheProgress.type = ProgressBarType.Cacher;
        downloadProgress = new ProgressBar();
        downloadProgress.type = ProgressBarType.Download;

        /* Callbacks for downloads */
        fetchContext.onComplete.connect(&onComplete);
        fetchContext.onFail.connect(&onFail);
        fetchContext.onProgress.connect(&onProgress);
    }

    /**
     * Close the Client/Registry
     */
    void close() @safe
    {
        _registry.close();
        stateDB.close();
        _cache.close();
        layoutDB.close();
        installDB.close();
    }

    /**
     * Access to the Installation
     *
     * Returns: const reference
     */
    pure @property const(Installation) installation() @safe @nogc nothrow const
    {
        return _installation;
    }

    /**
     * Access to dependency registry
     *
     * Returns: reference
     */
    pure @property RegistryManager registry() @safe @nogc nothrow
    {
        return _registry;
    }

    /**
     * Access to Remote management
     */
    pure @property RemoteManager remotes() @safe @nogc nothrow
    {
        return remoteManager;
    }

    /**
     * User interface implementation
     */
    pure @property UserInterface ui() @safe @nogc nothrow
    {
        return _ui;
    }

    /**
     * Return the fetch controller
     */
    pure @property FetchContext fetchContext() @safe @nogc nothrow
    {
        return fc;
    }

    /**
     * Return the System Cache
     */
    pure @property SystemCache cache() @safe @nogc nothrow
    {
        return _cache;
    }

    /**
     * Access CobblePlugin to load things.
     *
     * Returns: CobblePlugin
     */
    pure @property CobblePlugin cobbler() @safe @nogc nothrow
    {
        return cobble;
    }

    /**
     * Apply the transaction
     *
     * This will perform any caching + downloading up-front using the
     * .ui object for output.
     *
     * Throws: enforce() exception to ensure input isn't jank
     * Params:
     *      tx = Registry transaction
     */
    void applyTransaction(scope Transaction tx) @safe
    {
        /* Clean any existing jobs. */
        () @trusted { workQueue.clear(); }();

        dlTotal = 0;
        dlCurrent = 0;
        cacheTotal = 0;
        cacheCurrent = 0;

        ProgressBar blitBar;
        auto application = tx.apply();
        enforce(tx.problems.empty, "applyTransaction: Expected zero problems");

        renderer = new Renderer();

        auto st = stateDB.createState(tx, application);
        string[] precacheItems;

        /* For all packages in state - form job queue */
        foreach (pkg; application)
        {
            Job job = pkg.fetch();
            /* Already installed. */
            if (job is null)
            {
                continue;
            }

            /* Is this available in our install already.. ? */
            immutable id = pkg.pkgID;
            if (installDB.metaDB.byID(id).pkgID == id)
            {
                tracef("Skipping cache of %s", pkg.pkgID);
                continue;
            }

            auto expHash = job.checksum();
            auto downloadPath = installation.cachePath("downloads", "v1",
                    expHash[0 .. 5], expHash[$ - 5 .. $]);
            downloadPath.mkdirRecurse();
            auto downloadPathFull = downloadPath.buildPath(expHash);
            job.destinationPath = downloadPathFull;

            auto expSize = job.expectedSize;

            /* TODO: Do we have it downloaded somewhere? */
            workQueue[job.remoteURI] = job;

            if (job.destinationPath.exists)
            {
                precacheItems ~= job.remoteURI;
                continue;
            }

            dlTotal += expSize;
            cacheTotal++;

            /* TODO: Set closure for caching + hash verification! */
            void threadCompletionHandler(immutable(Fetchable) f, long code) @trusted
            {
                if (code != 200 && code != 0)
                {
                    return;
                }
                cachePackage(f.sourceURI);
            }

            downloadProgress.total = downloadProgress.total + 1;

            /* Only fetch what is missing. */
            auto fc = Fetchable(job.remoteURI, job.destinationPath, expSize,
                    FetchType.RegularFile, &threadCompletionHandler);
            fetchContext.enqueue(fc);
        }

        immutable bool haveWork = workQueue.length > 0 || !precacheItems.empty;

        /* Can't have progress on no work.. */
        if (haveWork)
        {
            if (dlTotal > 0)
            {
                /* Space out the text */
                renderer.add(new Label());

                foreach (bar; fetchProgress)
                {
                    renderer.add(bar);
                }

                auto stepLabel = new Label(Text("Total downloaded").attr(Attribute.Underline));
                renderer.add(new Label());
                renderer.add(stepLabel);
                renderer.add(downloadProgress);
                renderer.add(new Label());
            }

            /* Cache regardless */
            cacheLabel = new Label(Text("Cache activity").attr(Attribute.Underline));
            renderer.add(cacheLabel);
            renderer.add(cacheProgress);
        }

        cacheTotal = workQueue.length;

        auto thr = new UIThread(renderer);
        () @trusted { thr.start(); }();

        while (!fetchContext.empty)
        {
            fetchContext.fetch();
        }

        foreach (pkg; precacheItems)
        {
            cachePackage(pkg);
        }

        /* Lets get ourselves a state ID */
        stateDB.save(st);

        synchronized (renderer)
        {
            renderer.redraw();
            renderer.add(new Label());
            renderer.add(new Label(Text("Blitting filesystem").attr(Attribute.Underline)));
            blitBar = new ProgressBar();
            blitBar.label = "Computing filesystem layout";
            blitBar.type = ProgressBarType.Blitter;
            renderer.add(blitBar);
            renderer.redraw();
        }

        auto sroot = new SystemRoot(_installation, _cache, st.id);
        foreach (pkg; application)
        {
            sroot.pushEntries(layoutDB.entries(pkg.pkgID));
        }
        sroot.apply(blitBar);

        thr.stop();

        /* Redraw and jump line */
        renderer.redraw();
        writeln();

        /* Finish writing the new transaction */
        finalizeRoot(st);

        /* TODO: Support /deferred/ swap */
        updateRootLayout();
        promoteStagingToLive(st);
        if (installation.activeState > 0)
        {
            archiveState(installation.activeState);
        }
    }

private:

    /**
     * Finalize the root prior to updating system pointer
     *
     * TODO: Run triggers + boot update
     */
    void finalizeRoot(scope ref State newState) @safe
    {
        import std.file : write;
        import std.path : dirName;
        import std.string : replace;

        auto szID = to!string(newState.id);
        static immutable osReleaseTemplate = import("os-release.in");

        /**
         * TODO: Support KERNEL and VERSION properly
         */
        auto outputFile = osReleaseTemplate.replace("@VERSION@", "borkytests")
            .replace("@TRANSACTION@", szID);

        auto osReleaseOutput = installation.stagingPath("usr", "lib", "os-release");
        auto osReleaseDir = osReleaseOutput.dirName;
        osReleaseDir.mkdirRecurse();
        osReleaseOutput.write(outputFile);
    }

    /**
     * Correct the filesystem layout for usrmerge
     */
    void updateRootLayout() @safe
    {
        atomicRootfsLink("usr/sbin", "sbin");
        atomicRootfsLink("usr/bin", "bin");
        atomicRootfsLink("usr/lib", "lib");
        atomicRootfsLink("usr/lib", "lib64");
        atomicRootfsLink("usr/lib32", "lib32");
    }

    /**
     * Atomically perform a link update
     *
     * Params:
     *      sourcePath = Source to link *from*
     *      targetPath = target to link *to*
     */
    void atomicRootfsLink(in string sourcePath, in string targetPath) @trusted
    {
        import std.file : remove, symlink, rename, exists, isSymlink, readLink;

        auto finalTarget = installation.joinPath(targetPath);
        auto stagingTarget = installation.joinPath(format!"%s.next"(targetPath));

        if (stagingTarget.exists)
        {
            stagingTarget.remove();
        }

        /* If the symlink is already correct, leave it be */
        if (finalTarget.exists && finalTarget.isSymlink && finalTarget.readLink() == sourcePath)
        {
            return;
        }

        /* Symlink staging link in now */
        symlink(sourcePath, stagingTarget);
        rename(stagingTarget, finalTarget);
    }

    /**
     * Promote the new staging tree to live
     */
    void promoteStagingToLive(scope const ref State newState) @safe
    {
        immutable usrSourceFull = installation.stagingPath("usr");
        immutable usrTargetFull = installation.joinPath("usr");

        /* We can only swap if a node for /usr exists in some fashion */
        if (!usrTargetFull.exists)
        {
            mkdirRecurse(usrTargetFull);
        }

        /* Hullo C */
        auto sourceZ = () @trusted { return usrSourceFull.toStringz; }();
        auto targetZ = () @trusted { return usrTargetFull.toStringz; }();

        immutable ret = () @trusted {
            return renameat2(AT_FDCWD, sourceZ, AT_FDCWD, targetZ, renameExchange);
        }();
        enforce(ret == 0, "Failed to promote staging to live. OHNO");
    }

    /**
     * Whatever *was* /usr, needs to now live in the archive
     *
     * Params:
     *      oldState = The last active state
     */
    void archiveState(StateID oldState) @safe
    {
        import std.file : isSymlink, rename;

        immutable szID = to!string(oldState);
        immutable statePathTarget = installation.rootPath(szID, "usr");
        immutable statePathSource = installation.stagingPath("usr");
        immutable stateTree = statePathTarget.dirName;

        /* Ensure root of old state tree exists. */
        if (!stateTree.exists)
        {
            stateTree.mkdirRecurse();
        }

        /* LEGACY: Just a symlink to /usr, the tree already exists in place */
        if (statePathSource.isSymlink)
        {
            return;
        }

        /* Now rename the internal staged usr (post-swap) into tx tree */
        statePathSource.rename(statePathTarget);
    }

    void onFail(Fetchable f, string failureMessage) @safe
    {
    }

    void onProgress(uint workerThread, Fetchable f, double total, double current) @safe
    {
        auto fp = fetchProgress[workerThread];
        fp.total = total;
        fp.current = current;
        fp.label = f.sourceURI.baseName;
    }

    /**
     * Download completed, cache it.
     */
    void onComplete(Fetchable f, long code) @safe
    {
        auto c = downloadProgress.current;
        c++;
        downloadProgress.current = c;
        downloadProgress.label = format!"%d out of %d"(cast(int) downloadProgress.current,
                cast(int) downloadProgress.total);
    }

    void cachePackage(string originURI) @trusted
    {
        synchronized (_cache)
        {
            auto job = workQueue[originURI];
            if (job.type != JobType.FetchPackage)
            {
                return;
            }

            auto r = new Reader(File(job.destinationPath, "rb"));
            scope (exit)
            {
                r.close();
            }
            MetaPayload mp = () @trusted { return r.payload!MetaPayload; }();
            immutable pkgID = job.checksum;
            if (pkgID.empty)
            {
                fatal(format!"Failed to cache %s"(job.destinationPath));
            }

            /* IMPORTANT: We need to re-add these index fields */
            mp.addRecord(RecordType.String, RecordTag.PackageHash, pkgID);
            mp.addRecord(RecordType.String, RecordTag.PackageSize, job.expectedSize);
            mp.addRecord(RecordType.String, RecordTag.PackageURI, job.remoteURI);

            /* Cache it */
            immutable precache = _cache.install(job.remoteURI.baseName, pkgID,
                    r, cacheProgress, true).match!((Success _) {
                /* Layout DB merge */
                return cast(CacheResult) layoutDB.install(pkgID, r).match!( /* InstallDB merge */
                    (Success _) { return cast(CacheResult) installDB.install(mp); }, (Failure f) {
                        return cast(CacheResult) f;
                    });
            }, (Failure f) { return cast(CacheResult) f; },);

            precache.match!((Success _) {}, (Failure fa) {
                errorf("Failure to cache pkg: %s", fa);
            });

            cacheCurrent++;
            cacheLabel.label = Text(format!"Cached %d of %d"(cacheCurrent,
                    cacheTotal)).attr(Attribute.Underline);
        }
    }

    Installation _installation;
    InstallDB installDB;
    RegistryManager _registry;
    StateDB stateDB;
    LayoutDB layoutDB;
    SystemCache _cache;
    RemoteManager remoteManager;
    UserInterface _ui;
    FetchController fc;
    ProgressBar[] fetchProgress;
    ProgressBar downloadProgress;
    CobblePlugin cobble;
    Label cacheLabel;
    ProgressBar cacheProgress;
    Renderer renderer;
    Job[string] workQueue;
    double dlTotal = 0;
    double dlCurrent = 0;
    ulong cacheTotal;
    ulong cacheCurrent;
}
