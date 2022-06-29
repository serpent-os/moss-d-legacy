/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.controller.rootconstructor
 *
 * Construct a rootfs for a given state ID.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.controller.rootconstructor;

import moss.storage.diskpool;
import moss.storage.db.statedb;
import moss.storage.db.layoutdb;
import moss.format.binary.payload.layout;
import moss.context;

import std.algorithm : sort, uniq, map, each, filter;
import std.array : array, join;
import std.conv : to;
import std.file : mkdirRecurse;
import std.path : dirName;

import moss.core.ioutil;
import std.sumtype : tryMatch;
import moss.core : FileType;

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
    void construct(scope State newState)
    {
        /* Copy all installed candidates */
        auto finalLayouts = newState.selections.map!((s) => layoutDB.entries(s.target)).join;
        finalLayouts.sort!((esA, esB) => esA.target < esB.target);

        /* Build set of layouts for all candidates */

        /* Ensure we have a rootfs dir for root level nodes */
        auto rootfsDir = join([
            context.paths.store, "root", to!string(newState.id), "usr"
        ], "/");
        rootfsDir.mkdirRecurse();

        /* Apply unique layouts */
        finalLayouts.uniq!((esA, esB) => esA.target == esB.target)
            .each!((es) => applyLayout(newState, es, rootfsDir));
    }

private:

    void applyLayout(scope State newState, ref EntrySet es, in string rootfsDir)
    {
        import std.array : join;
        import std.conv : to;
        import std.file : setAttributes, setTimes;

        /* /.moss/store/root/1 .. */
        auto targetNode = join([rootfsDir, es.target], "/");

        import std.file : mkdirRecurse, symlink;

        /* Handle basic file types now */
        switch (es.entry.type)
        {
        case FileType.Directory:
            targetNode.mkdirRecurse();
            targetNode.setAttributes(es.entry.mode);
            break;
        case FileType.Symlink:
            targetNode.dirName.mkdirRecurse();
            es.symlinkSource.symlink(targetNode);
            break;
        case FileType.Regular:
            targetNode.dirName.mkdirRecurse();
            auto sourcePath = diskPool.fullPath(cast(string) es.digestString());
            auto res = IOUtil.hardlink(sourcePath, targetNode);
            res.tryMatch!((bool b) => b);
            targetNode.setAttributes(es.entry.mode);

            break;
        default:
            break;
        }
    }

    DiskPool diskPool = null;
    StateDB stateDB = null;
    LayoutDB layoutDB = null;
}
