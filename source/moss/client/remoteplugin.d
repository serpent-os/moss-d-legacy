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
        return NullableRegistryItem(NullableRegistryItem.init);
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
     * Begin fetching of a specific item
     */
    override void fetchItem(FetchContext context, in string pkgID) @safe
    {
        MetaEntry item = db.byID(pkgID);
        auto uri = format!"%s/%s"(remoteConfig.uri.dirName, item.uri);
        auto expHash = item.hash;
        auto downloadPath = installation.cachePath("downloads", "v1",
                expHash[0 .. 5], expHash[$ - 5 .. $]);
        auto downloadPathFull = downloadPath.buildPath(expHash);
        downloadPath.mkdirRecurse();
        auto fj = Fetchable(uri, downloadPathFull, item.downloadSize, FetchType.RegularFile, null);
        context.enqueue(fj);
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
