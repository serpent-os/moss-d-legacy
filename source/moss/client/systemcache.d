/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.systemcache
 *
 * Asset management
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.systemcache;

public import moss.core.errors;
public import std.sumtype;
public import moss.client.installation;
public import std.stdint : uint64_t;

import moss.db.keyvalue;
import moss.db.keyvalue.errors;
import moss.db.keyvalue.orm;
import std.experimental.logger;
import std.file : exists;
import std.string : format;

/**
 * All SystemCache operations return a CacheResult
 */
public alias CacheResult = Optional!(Success, Failure);

/**
 * A CacheEntry is a mapping of the unique ID to a ref count
 */
public @Model struct CacheEntry
{
    /**
     * Unique (hash) identifier for the asset
     */
    @PrimaryKey string id;

    /**
     * How many times this particular entry has been referenced
     */
    uint64_t refCount;
}

/**
 * The SystemCache is the global disk pool of assets which
 * are shared between all filesystem transactions (install roots).
 * The implementation consists of naming facilities, methods to then
 * cache an asset, and finally some reference counting semantics.
 */
public final class SystemCache
{

    @disable this();

    /**
     * Construct a new SystemCache
     *
     * Params:
     *      installation = Initialised Installation instance
     */
    this(Installation installation) @safe
    {
        this.installation = installation;
    }

    /**
     * Attempt to open the SystemCache
     *
     * Returns: Success or Failure
     */
    CacheResult connect() @safe
    {
        immutable dbPath = installation.dbPath("syscache");
        tracef("SystemCache: %s", dbPath);
        auto flags = installation.mutability == Mutability.ReadWrite
            ? DatabaseFlags.CreateIfNotExists : DatabaseFlags.ReadOnly;

        /* We have no DB. */
        if (!dbPath.exists && installation.mutability == Mutability.ReadOnly)
        {
            return cast(CacheResult) fail(format!"SystemCache: Cannot find %s"(dbPath));
        }

        Database.open("lmdb://" ~ dbPath, flags).match!((Database db) {
            this.db = db;
        }, (DatabaseError err) { throw new Exception(err.message); });

        if (installation.mutability == Mutability.ReadWrite)
        {
            immutable err = db.update((scope tx) => tx.createModel!(CacheEntry));
            if (!err.isNull)
            {
                return cast(CacheResult) fail(err.message);
            }
        }
        return cast(CacheResult) Success();
    }

    /**
     * Close the underlying resources
     */
    void close() @safe
    {
        if (db is null)
        {
            return;
        }
        db.close();
        db = null;
    }

private:

    Installation installation;
    Database db;
}
