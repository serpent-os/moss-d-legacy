/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.storage.diskpool
 *
 * Provides hardlinking of hashed assets.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.storage.diskpool;

import moss.context;
import std.array : join;
import std.file : mkdirRecurse;

import moss.core : hardLink;

/**
 * Simple implementation for now, provide hardlinking of hashed assets
 */
final class DiskPool
{
    /**
     * Construct a new DiskPool within the target system
     */
    this()
    {
        rootDirectory = join([context.paths.store, "assets/v1"], "/");
        rootDirectory.mkdirRecurse();
    }

    /**
     * Return the full path of the input hash
     */
    string fullPath(const(string) inp)
    {
        if (inp.length >= 10)
        {
            return join([rootDirectory, inp[0 .. 5], inp[$ - 5 .. $], inp], "/");
        }

        return join([rootDirectory, inp], "/");
    }

    /**
     * Promote a local store item to the final path.
     * TODO: Increase refCount
     */
    void refAsset(const(string) inp, const(string) destination)
    {
        hardLink(fullPath(inp), destination);
    }

    /**
     * Return true if we have the given asset
     */
    bool contains(const(string) inp)
    {
        import std.file : exists;

        return fullPath(inp).exists;
    }

private:

    string rootDirectory = null;
}
