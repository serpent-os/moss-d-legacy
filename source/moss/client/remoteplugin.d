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

import moss.client.metadb;
import moss.core.errors;
import std.algorithm : map;
import std.array : array;
import std.sumtype;

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
        this._remoteConfig = remoteConfig;
        this.installation = installation;
        dbPath = installation.joinPath(".moss", "remotes", remoteConfig.id, "db");
        db = new MetaDB(dbPath, installation.mutability);

        db.connect.match!((Success _) {}, (Failure f) {
            throw new Error(f.message);
        });
    }

    /**
     * Support populating the db
     */
    auto loadFromIndex(string indexFile) @safe
    {
        return db.loadFromIndex(indexFile);
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
    override ItemInfo info(in string pkgID) @trusted const
    {
        auto dbi = cast(MetaDB) db;
        return dbi.info(pkgID);
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
    override const(RegistryItem)[] list(in ItemFlags flags) @trusted const
    {
        auto dbi = cast(MetaDB) db;
        return dbi.list().map!((entry) {
            static immutable flags = ItemFlags.Available;
            return RegistryItem(entry.pkgID, cast(RegistryPlugin) this, flags);
        }).array();
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
        db.close();
    }

    /**
     * Remote configuration
     */
    pure @property auto remoteConfig() @safe @nogc nothrow const
    {
        return _remoteConfig;
    }

private:

    Repository _remoteConfig;
    Installation installation;
    string dbPath;
    MetaDB db;
}
