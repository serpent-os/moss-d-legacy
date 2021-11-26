/*
 * This file is part of moss.
 *
 * Copyright © 2020-2021 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module moss.controller;

import moss.context;

import moss.storage.pool;
import moss.storage.db.cachedb;
import moss.storage.db.packagesdb;
import moss.storage.db.layoutdb;
import moss.storage.db.statedb;

import moss.deps.registry;
import moss.controller.plugins;

import moss.controller.archivecacher;
import moss.controller.rootconstructor;
import std.algorithm : each, filter, canFind;
import std.array : array;

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
        import std.stdio : writeln;

        RegistryItem[] removals;

        foreach (pkg; packages)
        {
            auto localCandidate = registryManager.byName(pkg, ItemFlags.Installed);
            if (localCandidate.empty)
            {
                writeln("Cannot find package: ", pkg);
                return;
            }
            removals ~= localCandidate.front;
        }

        auto tx = registryManager.transaction();
        tx.removePackages(removals);
        commitTransaction(tx);
    }

    /**
     * Request installation of the given packages
     */
    void installPackages(in string[] paths)
    {
        import std.stdio : writeln;
        import std.file : exists;
        import std.string : endsWith;

        auto localPaths = paths.filter!((p) => p.endsWith(".stone") && p.exists).array();
        auto repoPaths = paths.filter!((p) => !p.endsWith(".stone")).array();
        auto wonkyPaths = paths.filter!((p) => !localPaths.canFind(p) && !repoPaths.canFind(p));

        /* No wonky paths please */
        if (!wonkyPaths.empty)
        {
            writeln("Cannot find the following packages: ", wonkyPaths);
            return;
        }

        /* Not yet doing repos,sorry */
        if (repoPaths.length > 0)
        {
            writeln("Repository installation not yet supported");
            return;
        }

        /* Seriously, gimme some local archives */
        if (localPaths.length < 1)
        {
            writeln("Must provide local paths to install");
            return;
        }

        /* Load each path into the cobble db */
        localPaths.each!((p) => cobble.load(p));

        auto tx = registryManager.transaction();
        tx.installPackages(cobble.items.array);
        commitTransaction(tx);
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

        auto rootfsDir = buildPath(".moss", "store", "root", to!string(currentState.id));

        /* Construct the primary usr link */
        auto usrSource = rootfsDir.buildPath("usr");
        atomicRootfsLink(usrSource, "usr");

        /* Compat links to make usrmerge work */
        atomicRootfsLink("usr/bin", "bin");
        atomicRootfsLink("usr/lib", "lib");
        atomicRootfsLink("usr/lib", "lib64");
        atomicRootfsLink("usr/lib32", "lib32");
    }

private:

    void atomicRootfsLink(in string sourcePath, in string targetPath)
    {
        import std.file : remove, symlink, rename, exists, isSymlink, readLink;
        import std.string : format;
        import std.stdio : writeln;

        auto finalTarget = context.paths.root.buildPath(targetPath);
        auto stagingTarget = context.paths.root.buildPath(format!"%s.next"(targetPath));

        auto resolvedSource = context.paths.root.buildPath(sourcePath);

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

    void commitTransaction(Transaction tx)
    {
        import std.stdio : writeln, writefln;
        import std.conv : to;

        auto finalSet = tx.apply();
        auto problems = tx.problems();
        if (problems.length > 0)
        {
            writeln("The following problems were discovered: \n");
            foreach (problem; problems)
            {
                switch (problem.type)
                {
                case TransactionProblemType.MissingDependency:
                    writefln(" - %s depends on missing provider %s",
                            problem.item.pkgID, problem.dependency.to!string);
                    break;
                default:
                    writeln(problem);
                    break;
                }
            }
            writeln("\nNo changes have been made to your installation");
            return;
        }

        if (tx.removedItems.length > 0)
        {
            writeln("The following packages will be removed:");
            foreach (it; tx.removedItems)
            {
                writeln(" - ", it.info.name);
            }
        }

        /* TODO: Respect some real "manual" vs "automatic" logic in future. */
        auto state = new State();
        foreach (item; finalSet)
        {
            state.markSelection(item.pkgID, SelectionReason.ManuallyInstalled);

            /* Get it cached for cobble */
            if (item.plugin == cobble)
            {
                archiveCacher.cache(cobble.itemPath(item.pkgID));
            }
        }
        stateDB.addState(state);
        stateDB.activeState = state.id;
        writeln("Blitting filesystem");
        rootContructor.construct(state);
        writeln("Updating system pointer to: ", state.id);
        updateSystemPointer(state);
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
}
