/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.systemroot
 *
 * Remote Management API
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.client.systemroot;

public import std.stdint : uint64_t;
public import moss.core.errors;
public import moss.format.binary.payload.layout;
public import moss.client.systemcache;

import std.algorithm : count;
import std.container.rbtree;
import std.conv : to;
import std.path : dirName;
import moss.client.installation;
import moss.core : FileType;
import std.string : format;
import moss.client.progressbar;
import moss.core.ioutil;
import std.file : symlink, mkdirRecurse, setAttributes;

public alias RootResult = Optional!(Success, Failure);

alias EntryTree = RedBlackTree!(EntrySet, (a, b) {
    auto aC = a.target.count("/");
    auto bC = b.target.count("/");
    return aC != bC ? aC < bC : a.target < b.target;
}, false);

/**
 * Encapsulation and construction of new system roots
 * Each construction is performed within the global staging tree.
 */
public final class SystemRoot
{
    @disable this();

    /**
     * Construxt new SystemRoot with the given ID
     */
    this(Installation installation, SystemCache cache, uint64_t rootID) @safe
    {
        this.installation = installation;
        this.cache = cache;
        _rootID = rootID;
        systemEntries = new EntryTree();
    }

    /**
     * Root/State ID
     */
    pure @property uint64_t rootID() @safe @nogc nothrow const
    {
        return _rootID;
    }

    void pushEntries(EntrySet[] entries) @safe
    {
        systemEntries.insert(entries);
    }

    /**
     * Apply the transaction to disk
     */
    void apply(ProgressBar blitBar) @safe
    {
        import std.experimental.logger : infof;

        blitBar.total = systemEntries.length;

        string stateID = to!string(_rootID);
        string madeDir = null;
        auto usrDir = installation.stagingPath("usr");
        usrDir.mkdirRecurse();

        /* Construct the stateID finaliser file */
        {
            import std.file : write;

            auto statePath = installation.stagingPath("usr", ".stateID");
            statePath.write(stateID);
        }

        /* Walk the entries, ordered, apply */
        foreach (entry; systemEntries[])
        {
            auto fpName = installation.stagingPath("usr", entry.target);
            auto fpDir = fpName.dirName;

            scope (exit)
            {
                blitBar.current = blitBar.current + 1;
                blitBar.label = format!"%s of %s entries"(blitBar.current, blitBar.total);
            }

            /* Ensure we have the parent directory */
            if (madeDir != fpDir)
            {
                fpDir.mkdirRecurse();
                madeDir = fpDir;
            }

            switch (entry.entry.type)
            {
            case FileType.Directory:
                fpName.mkdirRecurse();
                fpName.setAttributes(entry.entry.mode);
                break;
            case FileType.Symlink:
                entry.symlinkSource.symlink(fpName);
                break;
            case FileType.Regular:
                auto fullSP = cache.fullPath(cast(string) entry.digestString);
                auto res = IOUtil.hardlink(fullSP, fpName);
                fpName.setAttributes(entry.entry.mode);
                break;
            default:
            }
        }
    }

private:

    uint64_t _rootID = 0;
    EntryTree systemEntries;
    Installation installation;
    SystemCache cache;
}
