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
import std.exception : enforce;
import std.experimental.logger;
import std.range : empty;
import moss.client.label : Label;
import moss.client.progressbar : ProgressBar;
import moss.client.renderer : Renderer;
import std.path : baseName;

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
        stateDB = new StateDB(_installation);
        stateDB.connect.match!((Failure f) => fatalf(f.message), (_) {});

        layoutDB = new LayoutDB(_installation);
        layoutDB.connect.match!((Failure f) => fatalf(f.message), (_) {});

        foreach (i; 0 .. 8)
        {
            fetchProgress ~= new ProgressBar();
        }
        totalProgress = new ProgressBar();
        totalProgress.special = true;

        fetchContext.onComplete.connect(&onComplete);
        fetchContext.onFail.connect(&onFail);
        fetchContext.onProgress.connect(&onProgress);
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

    /**
     * Apply the transaction
     *
     * This will perform any caching + downloading up-front using the
     * .ui object for output.
     *
     * Throws: enforce() exception to ensure input isn't jank
     * Params:
     *      tx = Registry transaction
     */
    void applyTransaction(scope Transaction tx) @safe
    {
        auto application = tx.apply();
        enforce(tx.problems.empty, "applyTransaction: Expected zero problems");
        enforce(!application.empty, "applyTransaction: Expected valid application");

        renderer = new Renderer();

        foreach (pkg; application)
        {
            pkg.fetch(fetchContext);
            totalProgress.total = totalProgress.total + 1;
        }

        /* Space out the text */
        renderer.add(new Label());

        foreach (bar; fetchProgress)
        {
            renderer.add(bar);
        }

        renderer.add(new Label(Text("Total downloaded").attr(Attribute.Underline)));
        renderer.add(totalProgress);

        while (!fetchContext.empty)
        {
            fetchContext.fetch();
        }
        renderer.redraw();
        import std.stdio : writeln;

        writeln();
    }

private:

    void onFail(Fetchable f, string failureMessage) @safe
    {
    }

    void onProgress(uint workerThread, Fetchable f, double total, double current) @safe
    {
        auto fp = fetchProgress[workerThread];
        fp.total = total;
        fp.current = current;
        fp.label = f.sourceURI.baseName;
        if (renderer !is null)
        {
            renderer.draw();
        }
    }

    void onComplete(Fetchable f, long code) @safe
    {
        auto c = totalProgress.current;
        c++;
        totalProgress.current = c;
        totalProgress.label = format!"%d out of %d"(cast(int) totalProgress.current,
                cast(int) totalProgress.total);
    }

    Installation _installation;
    RegistryManager _registry;
    StateDB stateDB;
    LayoutDB layoutDB;
    RemoteManager remoteManager;
    UserInterface _ui;
    FetchController fc;
    ProgressBar[] fetchProgress;
    ProgressBar totalProgress;
    Renderer renderer;
}
