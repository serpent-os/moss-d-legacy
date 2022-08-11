/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client
 *
 * Client API for moss
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.impl;

import core.sys.posix.unistd : geteuid;

/**
 * Provides high-level access to the moss system
 */
public final class MossClient
{
    /**
     * Initialise a MossClient with the given root dir
     */
    this(in string root = "/") @safe
    {
        _root = root;

        /* Determine immediately if we have root permissions */
        if (geteuid() != 0)
        {
            readOnly = true;
        }
    }

    /**
     * Set the root directory for this client
     *
     * Params:
     *      dir = Rootfs directory
     */
    pure @property void root(in string dir) @safe @nogc nothrow
    {
        _root = dir;
    }

    /**
     * Root property
     *
     * Returns: Configured root directory
     *
     */
    pure @property string root() @safe @nogc nothrow const
    {
        return _root;
    }

private:

    /**
     * Root directory for all ops
     */
    string _root = null;
    bool readOnly;
}
