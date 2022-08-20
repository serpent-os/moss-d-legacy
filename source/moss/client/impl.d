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

import moss.client.installation;
import moss.deps.registry;
import moss.client.statedb;
import moss.config.repo;
import moss.config.io.configuration;

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
        _installation = new Installation(root);
        _registry = new RegistryManager();
        readRepos();
        stateDB = new StateDB(_installation);
    }

    /**
     * Close the Client/Registry
     */
    void close() @safe
    {
        _registry.close();
        stateDB.close();
    }

    /** API METHODS */
    int addRemote(string identifier, string origin) @safe
    {
        return 1;
    }

    /**
     * Access to the Installation
     *
     * Returns: const reference
     */
    pure @property const(Installation) installation() @safe @nogc nothrow const
    {
        return _installation;
    }

    /**
     * Access to dependency registry
     *
     * Returns: const reference
     */
    pure @property const(RegistryManager) registry() @safe @nogc nothrow const
    {
        return _registry;
    }

private:

    /**
     * Read the repos in and start doing something useful with them
     */
    void readRepos() @safe
    {
        auto config = new RepositoryConfiguration();
        () @trusted { config.load(_installation.root); }();
        debug
        {
            import std.stdio : writeln;

            writeln(config.sections);
        }
    }

    Installation _installation;
    RegistryManager _registry;
    StateDB stateDB;
}
