/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.remotes
 *
 * Remote Management API
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.remotes;

public import moss.config.repo;
public import moss.client.installation;
public import moss.core.errors;

import moss.client.remoteplugin;
import moss.core.fetchcontext;
import moss.deps.registry;
import std.algorithm : map;
import std.conv : to;
import std.experimental.logger;
import std.file : mkdirRecurse;
import std.path : baseName, dirName;
import std.string : format;
import std.uni : isAlphaNum, toLower;

alias RemoteResult = Optional!(Success, Failure);

/**
 * Manage various system remotes - whether they're source or binary.
 */
public final class RemoteManager
{

    /**
     * Initialise the RemoteManager with the given Installation
     */
    this(RegistryManager registry, FetchContext fetch, Installation install) @safe
    {
        this.registry = registry;
        this.installation = install;
        this.fetch = fetch;
        reloadConfiguration();
    }

    /**
     * Reload the configuration
     */
    void reloadConfiguration() @safe
    {
        auto config = new RepositoryConfiguration();
        () @trusted { config.load(installation.root); }();
        remotes = config.sections;

        foreach (plugin; plugins)
        {
            registry.removePlugin(plugin);
        }
        plugins = [];
        foreach (ref remoteConfig; remotes)
        {
            auto plugin = new RemotePlugin(remoteConfig, installation);
            registry.addPlugin(plugin);
            plugins ~= plugin;
        }
    }

    /**
     * Active configuration
     */
    pure auto @property active() @safe @nogc nothrow const
    {
        return remotes;
    }

    /**
     * Add a new remote
     *
     * Params:
     *      identifier = Unique identifier for the remote
     *      origin = Where to download things from.
     * Returns: A RemoteResult
     */
    RemoteResult add(string identifier, string origin, string description, uint64_t priority = 0) @safe
    {
        import std.file : write;

        /**
         * Mutable only!
         */
        if (installation.mutability != Mutability.ReadWrite)
        {
            return cast(RemoteResult) fail("Cannot add remote to non-mutable system");
        }

        immutable saneID = identifier.map!((m) => (m.isAlphaNum ? m : '_').toLower)
            .to!string;
        immutable confFile = installation.joinPath("etc", "moss", "repos.conf.d", saneID ~ ".conf");
        immutable data = format!`
- %s:
    description: "%s"
    uri: "%s"
    priority: %s
`(saneID, description, origin, priority);
        trace(format!"New config at: %s"(confFile));
        confFile.dirName.mkdirRecurse();

        write(confFile, data);

        auto remotePath = installation.joinPath(".moss", "remotes", saneID);
        remotePath.mkdirRecurse();

        return refresh();
    }

    /**
     * Remove an existing remote
     *
     * Params:
     *      identifier = Unique identifier for the remote
     * Returns: A RemoteResult
     */
    RemoteResult remove(string identifier) @safe
    {
        import std.file : remove, rmdirRecurse;

        /**
         * Mutable only!
         */
        if (installation.mutability != Mutability.ReadWrite)
        {
            return cast(RemoteResult) fail("Cannot remove remote to non-mutable system");
        }

        immutable saneID = identifier.map!((m) => (m.isAlphaNum ? m : '_').toLower)
            .to!string;
        immutable confFile = installation.joinPath("etc", "moss", "repos.conf.d", saneID ~ ".conf");
        auto remotePath = installation.joinPath(".moss", "remotes", saneID);
        confFile.remove();
        remotePath.rmdirRecurse();

        return cast(RemoteResult) Success();
    }

    /**
     * Refresh all of the remotes
     *
     * Returns: RemoteResult
     */
    RemoteResult refresh() @safe
    {
        reloadConfiguration();
        foreach (ref rm; remotes)
        {
            auto destPath = installation.joinPath(".moss", "remotes", rm.id, rm.uri.baseName);
            destPath.dirName.mkdirRecurse();
            auto fetchable = Fetchable(rm.uri, destPath, 0, FetchType.RegularFile, null);
            fetch.enqueue(fetchable);
        }

        /**
         * Fetch all of our fetchables
         */
        while (!fetch.empty)
        {
            fetch.fetch();
        }

        /* Reload the indexes */
        foreach (ref plugin; plugins)
        {
            immutable indexFile = installation.joinPath(".moss", "remotes",
                    plugin.remoteConfig.id, plugin.remoteConfig.uri.baseName);
            info(format!"Rebuilding indices on `%s`"(plugin.remoteConfig.id));

            auto remotePath = installation.joinPath(".moss", "remotes", plugin.remoteConfig.id);
            remotePath.mkdirRecurse();
            plugin.loadFromIndex(indexFile).match!((Failure f) {
                error(format!"Failed to refresh plugin: %s"(f.message));
            }, (_) {});
        }

        return cast(RemoteResult) Success();
    }

private:

    Repository[] remotes;
    Installation installation;
    FetchContext fetch;
    RemotePlugin[] plugins;
    RegistryManager registry;
}
