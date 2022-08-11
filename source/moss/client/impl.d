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
    }

    /**
     * Set the root directory for this client
     */
    pure @property void root(in string dir) @safe @nogc nothrow
    {
        _root = dir;
    }

    /**
     * Root property
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
}
