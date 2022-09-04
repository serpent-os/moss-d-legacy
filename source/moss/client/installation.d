/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.installation
 *
 * Introspection around the specified installation
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.installation;

import core.sys.posix.unistd : geteuid, access, W_OK;
import std.file : mkdirRecurse, exists;
import std.experimental.logger;

/**
 * System mutability - do we have readwrite?
 */
public enum Mutability
{
    /**
     * We only have readonly access
     */
    ReadOnly = 0,

    /**
     * We have read-write access
     */
    ReadWrite,
}

/**
 * Represenative of an installation, from scanning
 * a tree.
 */
public final class Installation
{
    /**
     * Construct an Installation object and get the basics
     * up and running
     */
    this(string root = "/") @safe
    {
        _root = root;

        /* We're good to go. */
        if (geteuid() == 0)
        {
            _mut = Mutability.ReadWrite;
            return;
        }

        /* Potential read-write? Root MUST exist */
        immutable canWrite = () @trusted {
            import std.string : toStringz;

            return access(_root.toStringz, W_OK) == 0;
        }();
        _mut = canWrite ? Mutability.ReadWrite : Mutability.ReadOnly;

        tracef("Mutability: %s", _mut);
        tracef("Root dir: %s", _root);
        tracef("canWrite: %s", canWrite);
    }

    /**
     * Ensure all support directories are in place
     */
    void ensureDirectories() @safe
    {
        if (_mut != Mutability.ReadWrite)
        {
            return;
        }

        foreach (ref dir; [
            joinPath(".moss", "db"), joinPath(".moss", "cache"),
            joinPath(".moss", "remotes"),
        ])
        {
            if (dir.exists)
            {
                continue;
            }
            tracef("Construct: %s", dir);
            dir.mkdirRecurse();
        }
    }

    /**
     * System mutability - affects DB/disk ops
     *
     * Returns: Mutability property
     */
    pure @property Mutability mutability() @safe @nogc nothrow const
    {
        return _mut;
    }

    /**
     * Root directory
     *
     * Returns: Where the installation is ("/" or somewhere else)
     */
    pure @property string root() @safe @nogc nothrow const
    {
        return _root;
    }

    /**
     * Variadic joinpath that "just werks"
     */
    pure auto joinPath(S...)(S p) @safe const
    {
        import std.conv : to;
        import std.algorithm : joiner;
        import std.string : endsWith;

        return () @trusted {
            auto RoR = [_root.endsWith("/") ? _root[0 .. $ - 1]: _root, p[0 .. $]];
            return joiner(RoR, "/",).to!string;
        }();
    }

    /**
     * Join the root dbPath
     */
    pure string dbPath(S...)(S p) @safe const
    {
        return joinPath(".moss", "db", p);
    }

    /**
     * Join the system caching path
     */
    pure auto cachePath(S...)(S p) @safe const
    {
        return joinPath(".moss", "cache", p);
    }

    /**
     * Join the system assets path
     */
    pure auto assetsPath(S...)(S p) @safe const
    {
        return joinPath(".moss", "assets", p);
    }

    /**
     * Root paths (install roots)
     */
    pure auto rootPath(S...)(S p) @safe const
    {
        return joinPath(".moss", "root", p);
    }

private:
    Mutability _mut = Mutability.ReadOnly;
    string _root = "/";
}
