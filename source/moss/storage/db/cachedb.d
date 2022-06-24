/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.storage.db.cachedb
 *
 * The CacheDB stores various system wide cache asset refcounts, such that
 * assets can safely be dropped when they are no longer needed.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.storage.db.cachedb;

import moss.context;
import moss.db;
import moss.db.rocksdb;
import std.stdint : uint64_t, int64_t;

/**
 * The CacheDB stores various system wide cache asset refcounts so that
 * they can safely be dropped when no longer needed.
 */
final class CacheDB
{

    /** 
     * Construct a new CacheDB, immediately reload it
     */
    this()
    {
        reloadDB();
    }

    ~this()
    {
        close();
    }

    /**
     * Ensure we close underlying handle
     */
    void close()
    {
        if (db is null)
        {
            return;
        }
        db.close();
        db.destroy();
        db = null;
    }

    /**
     * Forcibly reload the database
     */
    void reloadDB()
    {
        if (db !is null)
        {
            db.close();
            db.destroy();
            db = null;
        }

        /* Recreate DB now */
        const auto path = join([context().paths.db, "cacheDB"], "/");
        db = new RDBDatabase(path, DatabaseMutability.ReadWrite);
    }

    /**
     * Increase the reference count for the given asset within bucketID.
     * Initial inclusion of an asset will always set the new refcount to
     * 1.
     */
    void refAsset(const(string) bucketID, const(string) assetID)
    {
        auto bucket = db.bucket(bucketID);
        uint64_t refcount = 0;

        /* Find stored value to increase */
        const auto refcountLookup = bucket.get!uint64_t(assetID);
        if (refcountLookup.found)
        {
            refcount = refcountLookup.value;
        }

        /* Always increment now */
        ++refcount;
        bucket.set(assetID, refcount);
    }

    /**
     * Decrease the reference count for the given asset within bucketID
     * Any asset reaching 0 will eventually be marked for garbage collection
     */
    void unrefAsset(const(string) bucketID, const(string) assetID)
    {
        auto bucket = db.bucket(bucketID);

        uint64_t refcount = 1;

        const auto refcountLookup = bucket.get!uint64_t(assetID);
        if (refcountLookup.found)
        {
            refcount = refcountLookup.value;
        }

        /* Don't wrap unsigned.. */
        if (refcount > 0)
        {
            refcount = (cast(int64_t) refcount) - 1;
        }

        /* Store decreased value */
        bucket.set(assetID, refcount);
    }

private:

    Database db = null;
}
