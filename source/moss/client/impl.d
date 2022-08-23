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
import std.experimental.logger;
import moss.client.remotes;
import moss.client.ui;
import moss.fetcher.controller;

import moss.client.remoteplugin;

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
        remoteManager = new RemoteManager(fc, _installation);
        stateDB = new StateDB(_installation);
        _ui.warn!"%s\n    moss is %s unstable\n"(Text("Warning").fg(Color.White)
                .attr(Attribute.Underline), Text("highly").attr(Attribute.Bold));

        stateDB.connect.match!((Failure f) => fatalf(f.message), (_) {});

        reloadPlugins();
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
     * Returns: const reference
     */
    pure @property const(RegistryManager) registry() @safe @nogc nothrow const
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

    /**
     * Hot-reload the DB
     */
    void reloadPlugins() @safe
    {
        if (_registry !is null)
        {
            _registry.close();
        }
        _registry = new RegistryManager();

        /* Reload the remotes */
        foreach (rm; remotes.active)
        {
            auto plugin = new RemotePlugin(rm, _installation);
            _registry.addPlugin(plugin);
        }
    }

    Installation _installation;
    RegistryManager _registry;
    StateDB stateDB;
    RemoteManager remoteManager;
    UserInterface _ui;
    FetchController fc;
}
