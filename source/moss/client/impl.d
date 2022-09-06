/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client
 *
 * Client API for moss
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.impl;

import moss.client.installation;
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
import moss.format.binary.payload.meta : MetaPayload;
import moss.format.binary.reader : Reader;
import std.exception : enforce;
import std.experimental.logger;
import std.path : baseName;
import std.range : empty;
import std.stdio : File, writeln;
import std.string : endsWith, join;
import core.time;

import core.thread.osthread;

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
        fc = new FetchController(4);
        _ui = new UserInterface();
        _installation = new Installation(root);
        _installation.ensureDirectories();
        _registry = new RegistryManager();
        _cache = new SystemCache(_installation);
        _cache.connect.match!((Failure f) => fatalf(f.message), (_) {});
        remoteManager = new RemoteManager(_registry, fc, _installation);
        stateDB = new StateDB(_installation);
        stateDB.connect.match!((Failure f) => fatalf(f.message), (_) {});

        layoutDB = new LayoutDB(_installation);
        layoutDB.connect.match!((Failure f) => fatalf(f.message), (_) {});

        foreach (i; 0 .. 4)
        {
            fetchProgress ~= new ProgressBar();
        }
        cacheProgress = new ProgressBar();
        cacheProgress.type = ProgressBarType.Cacher;
        totalProgress = new ProgressBar();
        totalProgress.type = ProgressBarType.Download;

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
        ProgressBar blitBar;
        auto application = tx.apply();
        enforce(tx.problems.empty, "applyTransaction: Expected zero problems");
        enforce(!application.empty, "applyTransaction: Expected valid application");

        renderer = new Renderer();

        auto st = stateDB.createState(tx, application);

        foreach (pkg; application)
        {
            pkg.fetch(fetchContext);
            totalProgress.total = totalProgress.total + 1;
        }

        /* Space out the text */
        renderer.add(new Label());

        foreach (bar; fetchProgress)
        {
            renderer.add(bar);
        }

        auto stepLabel = new Label(Text("Total downloaded").attr(Attribute.Underline));
        renderer.add(new Label());
        renderer.add(stepLabel);
        renderer.add(totalProgress);
        renderer.add(new Label());

        renderer.add(new Label(Text("Cache activity").attr(Attribute.Underline)));
        renderer.add(cacheProgress);

        auto thr = new UIThread(renderer);
        () @trusted { thr.start(); }();

        while (!fetchContext.empty)
        {
            fetchContext.fetch();
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

        /* Update system pointer */
        updateSystemPointer(st);
    }

private:

    void updateSystemPointer(scope ref State newState) @safe
    {
        import std.conv : to;

        auto rootfsDir = join([".moss/root", to!string(newState.id)], "/");

        /* Construct the primary usr link */
        auto usrSource = join([rootfsDir, "usr"], "/");
        atomicRootfsLink(usrSource, "usr");

        /* Compat links to make usrmerge work */
        atomicRootfsLink("usr/bin", "bin");
        atomicRootfsLink("usr/lib", "lib");
        atomicRootfsLink("usr/lib", "lib64");
        atomicRootfsLink("usr/lib32", "lib32");
    }

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
        auto c = totalProgress.current;
        c++;
        totalProgress.current = c;
        totalProgress.label = format!"%d out of %d"(cast(int) totalProgress.current,
                cast(int) totalProgress.total);

        if (!f.sourceURI.endsWith(".stone"))
        {
            return;
        }

        auto r = new Reader(File(f.destinationPath, "rb"));
        scope (exit)
        {
            r.close();
        }
        MetaPayload mp = () @trusted { return r.payload!MetaPayload; }();
        immutable pkgID = () @trusted { return mp.getPkgID(); }();

        /* Cache it */
        immutable precache = _cache.install(pkgID, r, cacheProgress, true).match!((Success _) {
            /* Layout DB merge */
            return cast(CacheResult) layoutDB.install(pkgID, r);
        }, (Failure f) { return cast(CacheResult) f; },);

        precache.match!((Success _) {}, (Failure fa) {
            errorf("Failure to cache pkg: %s", fa);
        });
    }

    Installation _installation;
    RegistryManager _registry;
    StateDB stateDB;
    LayoutDB layoutDB;
    SystemCache _cache;
    RemoteManager remoteManager;
    UserInterface _ui;
    FetchController fc;
    ProgressBar[] fetchProgress;
    ProgressBar totalProgress;
    ProgressBar cacheProgress;
    Renderer renderer;
}
