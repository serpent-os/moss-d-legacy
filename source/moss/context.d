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

module moss.context;

import std.path : absolutePath;
public import std.path : buildPath;
import std.concurrency : initOnce;

/**
 * Return the current shared Context for all moss operations
 */
MossContext context() @trusted
{
    return initOnce!_sharedContext(new MossContext());
}

/* Singleton instance */
private __gshared MossContext _sharedContext = null;

/**
 * Always free the loop instance during the module destructor
 */
shared static ~this()
{
    if (_sharedContext !is null)
    {
        _sharedContext.destroy();
        _sharedContext = null;
    }
}

/**
 * Helper to safely encapsulate the paths used within Moss
 */
public struct MossPaths
{

    /**
     * Return the root directory
     */
    pragma(inline, true) pure @property const(string) root() @safe @nogc nothrow const
    {
        return _root;
    }

    /**
     * Return the database directory
     */
    pragma(inline, true) pure @property const(string) db() @safe @nogc nothrow const
    {
        return _db;
    }

    /**
     * Return the cache directory
     */
    pragma(inline, true) pure @property const(string) cache() @safe @nogc nothrow const
    {
        return _cache;
    }

    /**
     * Return the store directory
     */
    pragma(inline, true) pure @property const(string) store() @safe @nogc nothrow const
    {
        return _store;
    }

    /**
     * Create necessary context directories
     */
    void mkdirs() @trusted const
    {
        import std.algorithm : each;
        import std.file : mkdirRecurse;

        [_root, _db, _cache, _store].each!(mkdirRecurse);
    }

package:

    /**
     * Update the root property, which in turn will update the related paths
     */
    pure @property void root(const(string) s) @safe
    {
        _root = absolutePath(s);
        _db = _root.buildPath(".moss", "db");
        _cache = _root.buildPath(".moss", "cache");
        _store = _root.buildPath(".moss", "store");
    }

private:

    string _root = null;
    string _db = null;
    string _cache = null;
    string _store = null;
}

/**
 * MossContext is responsible for baking shared resources and
 * sharing them across the codebase.
 */
public final class MossContext
{

    /**
     * Return the paths information
     */
    pure ref @property const(MossPaths) paths() @safe @nogc nothrow
    {
        return _paths;
    }

    /**
     * Update the root directory for all operations
     */
    void setRootDirectory(const(string) rootDir)
    {
        _paths.root = rootDir;
    }

private:

    /**
     * Construct a new MossContext with the default paths
     */
    this()
    {
        _paths = MossPaths();
        _paths.root = "/";
    }

    MossPaths _paths;
}
