/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.controller
 *
 * The moss controller class is responsible for managing access to various
 * moss functionality and the local filesystem.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.controller;

import moss.context;

import moss.storage.cachepool;
import moss.storage.diskpool;
import moss.storage.db.cachedb;
import moss.storage.db.packagesdb;
import moss.storage.db.layoutdb;
import moss.storage.db.statedb;

import moss.deps.registry;
import moss.controller.plugins;
import moss.fetcher;
import std.parallelism : totalCPUs;

import moss.controller.archivecacher;
import moss.controller.remote;
import moss.controller.rootconstructor;
import std.algorithm : each, filter, canFind, sort, uniq;
import std.array : array;
import std.experimental.logger;
import std.path : baseName;
import std.stdio : writefln;
import std.string : endsWith, format, startsWith;

/**
 * MossController is required to access the underlying Moss resources and to
 * manipulate the filesystem in any way.
 */
public final class MossController
{
    /**
     * Construct a new MossController
     */
    this()
    {
        /* bound to max 4 fetches, or 2 for everyone else. */
        fetchController = new FetchController(totalCPUs >= 4 ? 3 : 1);
        fetchController.onComplete.connect(&onComplete);
        fetchController.onFail.connect(&onFailed);

        /* TODO: Only do with R/w privs */
        context.paths.mkdirs();
        diskPool = new DiskPool();
        cacheDB = new CacheDB();
        layoutDB = new LayoutDB();
        _stateDB = new StateDB();
        _packagesDB = new SystemPackagesDB();
        _registryManager = new RegistryManager();
        cobble = new CobblePlugin();
        activePkgs = new ActivePackagesPlugin(_packagesDB, _stateDB);

        /* Seed the query manager */
        _registryManager.addPlugin(cobble);
        _registryManager.addPlugin(activePkgs);

        /* Initialise remote management */
        caching = new CachePool();
        remotes = new RemoteManager(caching);
        remotes.plugins.each!((p) => _registryManager.addPlugin(p));
    }

    /**
     * Close the MossController and all resources
     */
    void close()
    {
        cacheDB.close();
        layoutDB.close();
        stateDB.close();
        packagesDB.close();
        _registryManager.close();
    }

    /**
     * Missing dependency policy
     *
     * Returns: True if the depenedencies should be ignored
     */
    pure @property bool ignoreDependencies() @safe @nogc nothrow const
    {
        return _ignoreDependencies;
    }

    /**
     * Missing dependency policy
     *
     * Params:
     *      b   = Set to true to ignore missing dependencies
     */
    pure @property void ignoreDependencies(bool b) @safe @nogc nothrow
    {
        _ignoreDependencies = b;
    }

    /**
     * Return the underlying registryManager
     */
    pragma(inline, true) pure @property RegistryManager registryManager() @safe @nogc nothrow
    {
        return _registryManager;
    }

    /**
     * Request removal of the given packages
     */
    void removePackages(in string[] packages)
    {
        RegistryItem[] removals;

        foreach (pkg; packages)
        {
            auto localCandidate = registryManager.byName(pkg, ItemFlags.Installed);
            if (localCandidate.empty)
            {
                warning(format!"Cannot find package: %s"(pkg));
                return;
            }
            removals ~= localCandidate.front;
        }

        auto tx = registryManager.transaction();
        tx.removePackages(removals);
        commitTransaction(tx);
    }

    /**
     * Load a local stone file via the Cobble plugin to make it accessible to the
     * Registry system
     */
    RegistryItem loadLocalPackage(in string path)
    {
        return cobble.load(path);
    }

    /**
     * Request installation of the given packages
     */
    void installPackages(in string[] sourcePaths)
    {
        import std.file : exists;
        import std.string : endsWith;
        import std.exception : enforce;

        /* Remove all duplicates! */
        string[] paths = cast(string[]) sourcePaths;
        paths.sort();
        paths = paths.uniq.array();

        auto localPaths = paths.filter!((p) => p.endsWith(".stone") && p.exists).array();
        auto repoPaths = paths.filter!((p) => !p.endsWith(".stone")).array();
        auto wonkyPaths = paths.filter!((p) => !localPaths.canFind(p) && !repoPaths.canFind(p));

        /* No wonky paths please */
        if (!wonkyPaths.empty)
        {
            warning(format!"Cannot find the following packages: %s"(wonkyPaths));
            return;
        }

        /* Load each path into the cobble db */
        localPaths.each!((p) => loadLocalPackage(p));
        RegistryItem[] installables = cobble.items.array();

        foreach (name; repoPaths)
        {
            auto provName = fromString!Provider(name);
            auto candidates = registryManager.byProvider(provName.type, provName.target);
            enforce(!candidates.empty, "Package not found: " ~ provName.toString);
            installables ~= candidates.front;
        }

        auto tx = registryManager.transaction();
        tx.installPackages(installables);
        commitTransaction(tx);
    }

    /**
     * Handle updating of remotes. Internal API currently
     */
    void updateRemotes()
    {
        remotes.updateRemotes(fetchController);
        while (!fetchController.empty)
        {
            fetchController.fetch();
        }
    }

package:

    /**
     * Return a utility ArchiveCacher
     */
    ArchiveCacher archiveCacher()
    {
        return ArchiveCacher(packagesDB, layoutDB, diskPool);
    }

    /**
     * Return a utility RootConstructor
     */
    RootConstructor rootContructor()
    {
        return RootConstructor(diskPool, stateDB, layoutDB);
    }

    /**
     * Return the underlying SystemPackagesDB
     */
    pragma(inline, true) pure @property SystemPackagesDB packagesDB() @safe @nogc nothrow
    {
        return _packagesDB;
    }

    /**
     * Return the underlying StateDB handle
     */
    pragma(inline, true) pure @property StateDB stateDB() @safe @nogc nothrow
    {
        return _stateDB;
    }

    /**
     * Currently this repoints /usr. This may be extended to other directories in
     * future.
     */
    void updateSystemPointer(ref State currentState)
    {
        import std.conv : to;

        auto rootfsDir = join([".moss/store/root", to!string(currentState.id)], "/");

        /* Construct the primary usr link */
        auto usrSource = join([rootfsDir, "usr"], "/");
        atomicRootfsLink(usrSource, "usr");

        /* Compat links to make usrmerge work */
        atomicRootfsLink("usr/bin", "bin");
        atomicRootfsLink("usr/lib", "lib");
        atomicRootfsLink("usr/lib", "lib64");
        atomicRootfsLink("usr/lib32", "lib32");
    }

private:

    void onComplete(in Fetchable f, long code)
    {
        writefln!"Downloaded: %s"(f.sourceURI.baseName);

        /* TODO: Only take action if default action not present */
        if (!f.sourceURI.endsWith(".stone"))
        {
            return;
        }

        string finalPath = f.destinationPath;

        /* Is this a cachepool path? */
        auto hashed = f.destinationPath.baseName;
        if (hashed.endsWith(".partial"))
        {
            hashed = hashed[0 .. $ - ".partial".length];

            /* Promote to final tree */
            if (caching.hasStaging(hashed))
            {
                finalPath = caching.finalPath(hashed);
                caching.promote(hashed);
            }
        }

        /* Lets cache it now */
        synchronized (this)
        {
            archiveCacher.cache(finalPath);
            writefln!"Cached: %s"(f.sourceURI.baseName);
        }
    }

    void onFailed(in Fetchable f, in string reason)
    {
        writefln!"Failed to download '%s': %s"(f.sourceURI, reason);
    }

    void atomicRootfsLink(in string sourcePath, in string targetPath)
    {
        import std.file : remove, symlink, rename, exists, isSymlink, readLink;
        import std.string : format;

        auto finalTarget = join([context.paths.root, targetPath], "/");
        auto stagingTarget = join([
            context.paths.root, format!"%s.next"(targetPath)
        ], "/");

        auto resolvedSource = join([context.paths.root, sourcePath], "/");

        if (stagingTarget.exists)
        {
            stagingTarget.remove();
        }

        /* Stop promoting the link as the source is gone */
        if (!resolvedSource.exists)
        {
            if (finalTarget.exists)
            {
                finalTarget.remove();
            }
            return;
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
     * Fully bake and commit to the transaction
     */
    void commitTransaction(Transaction tx)
    {
        import std.conv : to;

        auto finalSet = tx.apply();
        auto newpkgs = finalSet.filter!((p) => !p.installed);

        /* Let's see if we have any problems. Bail out clause */
        auto problems = tx.problems();
        if (problems.length > 0)
        {
            error("The following problems were discovered: \n");
            foreach (problem; problems)
            {
                switch (problem.type)
                {
                case TransactionProblemType.MissingDependency:
                    error(format!" - %s depends on missing %s"(problem.item.info.name,
                            problem.dependency.to!string));
                    break;
                default:
                    error(problem);
                    break;
                }
            }
            if (!ignoreDependencies)
            {
                info("\nNo changes have been made to your installation");
                return;
            }
            warning(" - Continuing due to --ignore-dependency");
        }

        if (!newpkgs.empty)
        {
            info("The following NEW packages will be installed: ");
            foreach (n; newpkgs)
            {
                info(format!" - %s"(n.info.name));
            }
        }

        /* Iterate items to be removed */
        if (tx.removedItems.length > 0)
        {
            info("The following packages will be removed:");
            foreach (it; tx.removedItems)
            {
                info(format!" - %s"(it.info.name));
            }
        }

        if (!acquireMissingAssets(finalSet))
        {
            return;
        }

        /* TODO: Respect some real "manual" vs "automatic" logic in future. */
        auto state = new State();
        foreach (item; finalSet)
        {
            state.markSelection(item.pkgID, SelectionReason.ManuallyInstalled);

            /* Check where to cache from, if needed */
            switch (locality(item))
            {
            case AssetLocality.Cobble:
                /* Use cobble (local archives) */
                archiveCacher.cache(cobble.itemPath(item.pkgID));
                break;
            case AssetLocality.RemoteCached:
                /* Use cache if we didnt already precache it */
                if (!_packagesDB.hasID(item.pkgID))
                {
                    auto rp = cast(RepoPlugin) item.plugin;
                    auto finalPath = rp.finalCachePath(item.pkgID);
                    archiveCacher.cache(finalPath);
                }
                break;
            default:
                break;
            }
        }
        stateDB.addState(state);
        stateDB.activeState = state.id;
        info("Blitting filesystem");
        rootContructor.construct(state);
        info(format!"Updating system pointer to: %s"(state.id));
        updateSystemPointer(state);
    }

    /**
     * Acquire any missing system assets
     */
    bool acquireMissingAssets(in RegistryItem[] items)
    {
        import std.array : join;
        import std.algorithm : map;

        auto missingItems = items.filter!((i) => locality(i) == AssetLocality.None);
        if (missingItems.empty)
        {
            return true;
        }

        missingItems.each!((i) => (cast(RegistryItem) i).fetch(fetchController));

        while (!fetchController.empty)
        {
            fetchController.fetch();
        }

        return true;
    }

    /**
     * Determine locality of an asset
     */
    AssetLocality locality(in RegistryItem item)
    {
        import std.file : exists;

        /* Pre cached */
        if (_packagesDB.hasID(item.pkgID))
        {
            return AssetLocality.PackageDB;
        }
        if (item.plugin == cobble && !cobble.queryID(item.pkgID).isNull)
        {
            return AssetLocality.Cobble;
        }
        auto remotePlugin = cast(RepoPlugin) item.plugin;
        if (remotePlugin !is null)
        {
            if (remotePlugin.finalCachePath(item.pkgID).exists)
            {
                return AssetLocality.RemoteCached;
            }
        }
        return AssetLocality.None;
    }

    /* Storage */
    DiskPool diskPool = null;
    CacheDB cacheDB = null;
    LayoutDB layoutDB = null;
    StateDB _stateDB = null;
    SystemPackagesDB _packagesDB = null;

    /* Plugins */
    RegistryManager _registryManager = null;
    CobblePlugin cobble = null;
    ActivePackagesPlugin activePkgs = null;

    /* Downloadability (TM) */
    FetchController fetchController = null;

    /* Repositories! */
    RemoteManager remotes;

    /* Caching of downloads/archives */
    CachePool caching;

    bool _ignoreDependencies;
}

enum AssetLocality : uint8_t
{
    None = 0,
    PackageDB,
    Cobble,
    RemoteCached,
}
