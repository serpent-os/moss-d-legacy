/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.remoteplugin
 *
 * Implements a moss-deps plugin for remotes
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.remoteplugin;

public import moss.deps.registry;
public import moss.config.repo;
public import moss.client.installation;

/**
 * Instantiated from a Remote to provide access to
 * packages
 */
public final class RemotePlugin : RegistryPlugin
{

    @disable this();

    /**
     * Construct a new RemotePlugin
     */
    this(Repository remoteConfig, Installation installation) @safe
    {
        this.remoteConfig = remoteConfig;
        this.installation = installation;
    }

    /**
     * Examine MetaDB for matching providers
     */
    override RegistryItem[] queryProviders(in DependencyType type,
            in string matcher, ItemFlags flags = ItemFlags.None) @safe
    {
        return null;
    }

    /**
     * Get ItemInfo for specific pkgID
     */
    override ItemInfo info(in string pkgID) @safe const
    {
        return ItemInfo.init;
    }

    /**
     * Query the pkgID in the database
     */
    override NullableRegistryItem queryID(in string pkgID) @safe
    {
        return NullableRegistryItem(NullableRegistryItem.init);
    }

    /**
     * Return dependencies for the given pkgID
     */
    override const(Dependency)[] dependencies(in string pkgID) @safe const
    {
        return null;
    }

    /**
     * Return providers for the given pkgID
     */
    override const(Provider)[] providers(in string pkgID) @safe const
    {
        return null;
    }

    /**
     * Retrive a list of all pkgs matching the given flags
     */
    override const(RegistryItem)[] list(in ItemFlags flags) @safe const
    {
        return null;
    }

    /**
     * Begin fetching of a specific item
     */
    override void fetchItem(FetchContext context, in string pkgID) @safe
    {

    }

    /**
     * Close any allocated resources
     */
    override void close() @safe
    {

    }

private:

    Repository remoteConfig;
    Installation installation;
}
