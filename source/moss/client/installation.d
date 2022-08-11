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

private:
    Mutability _mut = Mutability.ReadOnly;
    string _root = "/";
}
