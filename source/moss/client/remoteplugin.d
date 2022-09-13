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
import std.file : mkdirRecurse;
import std.algorithm : map;
import std.array : array;
import std.sumtype;
import std.string : format;
import std.path : dirName, buildPath, baseName;

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
    override RegistryItem[] queryProviders(in ProviderType type, in string matcher,
            ItemFlags flags = ItemFlags.None) @trusted
    {
        if ((flags & ItemFlags.Available) != ItemFlags.Available && flags != ItemFlags.None)
        {
            return null;
        }
        return db.byProvider(type, matcher).map!((pkgID) => RegistryItem(pkgID,
                cast(RegistryPlugin) this, ItemFlags.Available)).array();
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
        auto entry = db.byID(pkgID);
        if (entry.pkgID == pkgID)
        {
            return NullableRegistryItem(RegistryItem(pkgID, this, ItemFlags.Available));
        }
        return NullableRegistryItem(RegistryItem.init);
    }

    /**
     * Return dependencies for the given pkgID
     */
    override const(Dependency)[] dependencies(in string pkgID) @trusted const
    {
        auto dbi = cast(MetaDB) db;
        auto item = dbi.byID(pkgID);
        return item.dependencies;
    }

    /**
     * Return providers for the given pkgID
     */
    override const(Provider)[] providers(in string pkgID) @trusted const
    {
        auto dbi = cast(MetaDB) db;
        auto item = dbi.byID(pkgID);
        return item.providers;
    }

    /**
     * Retrive a list of all pkgs matching the given flags
     */
    override const(RegistryItem)[] list(in ItemFlags flags) @trusted const
    {
        if ((flags & ItemFlags.Available) != ItemFlags.Available && flags != ItemFlags.None)
        {
            return null;
        }
        auto dbi = cast(MetaDB) db;
        return dbi.list().map!((entry) {
            return RegistryItem(entry.pkgID, cast(RegistryPlugin) this, ItemFlags.Available);
        }).array();
    }

    /**
     * Create job for fetching this item
     *
     * Params:
     *      pkgID = Unique package Identifier
     * Returns: Job with type FetchPackage
     */
    override Job fetchItem(in string pkgID) @safe
    {
        MetaEntry item = db.byID(pkgID);
        Job download = new Job(JobType.FetchPackage, pkgID);
        download.checksum = item.hash;
        download.remoteURI = format!"%s/%s"(remoteConfig.uri.dirName, item.uri);
        download.expectedSize = item.downloadSize;

        return download;
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

    /**
     * Priority as set by the remote config
     */
    override pure @property uint64_t priority() @safe @nogc nothrow const
    {
        return _remoteConfig.priority;
    }

private:

    Repository _remoteConfig;
    Installation installation;
    string dbPath;
    MetaDB db;
}
