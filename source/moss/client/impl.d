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
import moss.client.layoutdb;
import moss.client.remoteplugin;
import moss.client.remotes;
import moss.client.statedb;
import moss.client.ui;
import moss.config.io.configuration;
import moss.config.repo;
import moss.deps.registry;
import moss.fetcher.controller;
import std.experimental.logger;

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
        fc = new FetchController();

        _ui = new UserInterface();
        _installation = new Installation(root);
        _installation.ensureDirectories();
        _registry = new RegistryManager();
        remoteManager = new RemoteManager(_registry, fc, _installation);
        _ui.warn!"%s\n    moss is %s unstable\n"(Text("Warning").fg(Color.White)
                .attr(Attribute.Underline), Text("highly").attr(Attribute.Bold));

        stateDB = new StateDB(_installation);
        stateDB.connect.match!((Failure f) => fatalf(f.message), (_) {});

        layoutDB = new LayoutDB(_installation);
        layoutDB.connect.match!((Failure f) => fatalf(f.message), (_) {});
    }

    /**
     * Close the Client/Registry
     */
    void close() @safe
    {
        _registry.close();
        stateDB.close();
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
     * Returns: reference
     */
    pure @property RegistryManager registry() @safe @nogc nothrow
    {
        return _registry;
    }

    /**
     * Access to Remote management
     */
    pure @property RemoteManager remotes() @safe @nogc nothrow
    {
        return remoteManager;
    }

    /**
     * User interface implementation
     */
    pure @property UserInterface ui() @safe @nogc nothrow
    {
        return _ui;
    }

    /**
     * Return the fetch controller
     */
    pure @property FetchContext fetchContext() @safe @nogc nothrow
    {
        return fc;
    }

private:

    Installation _installation;
    RegistryManager _registry;
    StateDB stateDB;
    LayoutDB layoutDB;
    RemoteManager remoteManager;
    UserInterface _ui;
    FetchController fc;
}
