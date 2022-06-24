/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.storage.cachepool
 *
 * The CachePool is responsible for caching system wide assets such as downlaods.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.storage.cachepool;
import moss.context;
import std.path : dirName;
import std.string : format;
import std.file : mkdirRecurse, rename, remove, exists;
import std.sumtype : match;
import std.array : join;

/**
 * The CachePool is responsible for caching system wide assets such as downloads.
 */
public final class CachePool
{

    /**
     * Construct a new CachePool (v1)
     */
    this()
    {
        _rootDir = join([context.paths.cache, "downloads", "v1"], "/");
        _stagingDir = join([_rootDir, "staging"], "/");
        _publishedDir = join([_rootDir, "committed"], "/");

        _stagingDir.mkdirRecurse();
        _publishedDir.mkdirRecurse();
    }

    /**
     * Return the staging path for the given asset
     */
    pure auto stagingPath(in string inp)
    {
        return join([_stagingDir, format!"%s.partial"(inp)], "/");
    }

    /**
     * Return the final path for the given asset
     */
    pure auto finalPath(in string inp)
    {
        return join([_publishedDir, inp[0 .. 5], inp[$ - 5 .. $], inp], "/");
    }

    void promote(in string inp)
    {
        const auto stagingOrigin = stagingPath(inp);
        const auto finalDestination = finalPath(inp);
        const auto destdir = finalDestination.dirName;

        /* Ensure target directory exists */
        destdir.mkdirRecurse();
        rename(stagingOrigin, finalDestination);
    }

    /**
     * Remove a staging file
     */
    void removeStaging(in string inp)
    {
        const auto stagingOrigin = stagingPath(inp);
        stagingOrigin.remove();
    }

    /** 
     * Return true if the cache already contains this file
     */
    bool contains(in string p)
    {
        return finalPath(p).exists;
    }

    /**
     * Is this a valid staging path?
     */
    bool hasStaging(in string p)
    {
        return stagingPath(p).exists;
    }

private:

    string _rootDir = null;
    string _stagingDir = null;
    string _publishedDir = null;
}
