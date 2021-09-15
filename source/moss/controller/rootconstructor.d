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

module moss.controller.rootconstructor;

import moss.storage.pool;
import moss.storage.db.statedb;
import moss.storage.db.layoutdb;
import moss.format.binary.payload.layout;
import moss.context;

import std.algorithm : sort, uniq, map, each;
import std.array : array, join;
import std.stdio : writeln;
import std.conv : to;
import std.file : mkdirRecurse;

import moss.core.util : hardLink;

/**
 * Construct a rootfs for a given state ID
 */
package struct RootConstructor
{
    @disable this();

    /**
     * Create a new RootConstructor
     */
    this(DiskPool diskPool, StateDB stateDB, LayoutDB layoutDB)
    {
        this.diskPool = diskPool;
        this.stateDB = stateDB;
        this.layoutDB = layoutDB;
    }

    /**
    * Construct root snapshot for the given identifier
    */
    void construct(ref State newState)
    {
        /* Copy all installed candidates */
        auto installedCandidates = stateDB.entries(newState.id).array();
        auto finalLayouts = installedCandidates.map!((s) => layoutDB.entries(s.target)).join;
        finalLayouts.sort!((esA, esB) => esA.target < esB.target);

        /* Build set of layouts for all candidates */
        import std.stdio : writeln;

        /* Ensure we have a rootfs dir for root level nodes */
        auto rootfsDir = context.paths.store.buildPath("root", to!string(newState.id));
        rootfsDir.mkdirRecurse();
        finalLayouts.uniq!((esA, esB) => esA.target == esB.target)
            .each!((es) => applyLayout(newState, es));
    }

private:

    void applyLayout(ref State newState, ref EntrySet es)
    {
        import std.path : buildPath;
        import std.conv : to;

        /* /.moss/store/root/1 .. */
        auto targetNode = context.paths.store.buildPath("root",
                to!string(newState.id), es.target[1 .. $]);

        import moss.format.binary : FileType;
        import std.file : mkdirRecurse, symlink;

        /* Update attributes on the layout item. */
        void updateAttrs()
        {
            import std.file : setAttributes, setTimes;
            import std.datetime : SysTime;

            targetNode.setAttributes(es.entry.mode);
            targetNode.setTimes(SysTime.fromUnixTime(es.entry.time),
                    SysTime.fromUnixTime(es.entry.time));
        }

        /* Handle basic file types now */
        switch (es.entry.type)
        {
        case FileType.Directory:
            targetNode.mkdirRecurse();
            updateAttrs();
            break;
        case FileType.Symlink:
            es.source.symlink(targetNode);
            break;
        case FileType.Regular:
            auto sourcePath = diskPool.fullPath(es.source);
            hardLink(sourcePath, targetNode);
            updateAttrs();
            break;
        default:
            break;
        }
    }

    DiskPool diskPool = null;
    StateDB stateDB = null;
    LayoutDB layoutDB = null;
}
