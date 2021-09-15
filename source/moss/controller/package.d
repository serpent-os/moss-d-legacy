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
import moss.jobs;

import moss.storage.pool;
import moss.storage.db.cachedb;
import moss.storage.db.installdb;
import moss.storage.db.layoutdb;
import moss.storage.db.statedb;
import moss.query;

import moss.controller.archivecacher;
import moss.controller.changeprocessor;
import moss.controller.cacheprocessor;

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
        installDB = new InstallDB();
        _query = new QueryManager();

        /* Register the new CacheProcessor */
        mainLoop.systemGroup.append(new ChangeProcessor(this));
        mainLoop.systemGroup.append(new CacheProcessor(this));

        context.entityManager.build();
    }

    /**
     * Close the MossController and all resources
     */
    void close()
    {
        cacheDB.close();
        layoutDB.close();
        stateDB.close();
        installDB.close();
    }

    /**
     * Request installation of the given packages
     */
    void installPackages(in string[] paths)
    {
        import std.array : array;
        import std.algorithm : filter, canFind;
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

        /* Alright, go install now */
        context.jobs.pushJob(ChangeRequest(ChangeType.InstallArchives, cast(string[]) localPaths));
    }

package:

    /**
     * Return a utility ArchiveCacher
     */
    ArchiveCacher archiveCacher()
    {
        return ArchiveCacher(installDB, layoutDB, diskPool);
    }

    /**
     * Return the underlying StateDB handle
     */
    pragma(inline, true) pure @property StateDB stateDB() @safe @nogc nothrow
    {
        return _stateDB;
    }

    /**
     * Return the underlying QueryManager
     */
    pragma(inline, true) pure @property QueryManager queryManager() @safe @nogc nothrow
    {
        return _query;
    }

private:

    DiskPool diskPool = null;
    CacheDB cacheDB = null;
    LayoutDB layoutDB = null;
    StateDB _stateDB = null;
    InstallDB installDB = null;
    QueryManager _query = null;
}
