/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.context
 *
 * Define shared context for all moss operations.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.context;

import std.path : absolutePath;
public import std.array : join;
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
     * Return the remotes directory
     */
    pragma(inline, true) pure @property const(string) remotes() @safe @nogc nothrow const
    {
        return _remotes;
    }

    /**
     * Create necessary context directories
     */
    void mkdirs() @trusted const
    {
        import std.algorithm : each;
        import std.file : mkdirRecurse;

        [_root, _db, _cache, _store, _remotes].each!(mkdirRecurse);
    }

package:

    /**
     * Update the root property, which in turn will update the related paths
     */
    pure @property void root(const(string) s) @safe
    {
        _root = absolutePath(s);
        _db = join([_root, ".moss/db"], "/");
        _cache = join([_root, ".moss/cache"], "/");
        _store = join([_root, ".moss/store"], "/");
        _remotes = join([_root, ".moss/remotes"], "/");
    }

private:

    string _root = null;
    string _db = null;
    string _cache = null;
    string _store = null;
    string _remotes = null;
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
