/*
 * This file is part of moss-core.
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

module moss.storage.pool;

import moss.context;
import std.path : buildPath;
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
        rootDirectory = context.paths.store.buildPath("assets", "v1");
        rootDirectory.mkdirRecurse();
    }

    /**
     * Return the full path of the input hash
     */
    string fullPath(const(string) inp)
    {
        if (inp.length >= 10)
        {
            return rootDirectory.buildPath(inp[0 .. 5], inp[$ - 5 .. $], inp);
        }

        return rootDirectory.buildPath(inp);
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
