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

module moss.storage.cachepool;
import moss.context;
import std.path : buildPath, dirName;
import std.string : format;
import std.file : mkdirRecurse, rename, remove;
import moss.core.ioutil;
import std.sumtype : match;

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
        _rootDir = context.paths.cache.buildPath("v1");
        _stagingDir = _rootDir.buildPath("staging");
        _publishedDir = _rootDir.buildPath("committed");

        _stagingDir.mkdirRecurse();
        _publishedDir.mkdirRecurse();
    }

    /**
     * Return the staging path for the given asset
     */
    pure auto stagingPath(in string inp)
    {
        return _stagingDir.buildPath(format!"%s.partial"(inp));
    }

    /**
     * Return the final path for the given asset
     */
    pure auto finalPath(in string inp)
    {
        return _publishedDir.buildPath(inp[0 .. 5], inp[$ - 5 .. $], inp);
    }

    void promote(in string inp)
    {
        const auto stagingOrigin = stagingPath(inp);
        const auto finalDestination = finalPath(inp);
        const auto destdir = finalDestination.dirName;

        /* Ensure target directory exists */
        auto res = IOUtil.mkdir(destdir, octal!755, true);
        res.match!((bool b) {}, (err) { throw new Exception(res.toString); });

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
    pure bool contains(in string p)
    {
        return false;
    }

private:

    string _rootDir = null;
    string _stagingDir = null;
    string _publishedDir = null;
}
