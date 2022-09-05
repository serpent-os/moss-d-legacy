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
import std.file : exists, mkdirRecurse;
import std.string : format;
import moss.format.binary.reader;
import moss.format.binary.payload.content;
import moss.format.binary.payload.index;
import moss.core.ioutil;
import std.path : dirName;

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
            installation.cachePath("content").mkdirRecurse();
        }
        return cast(CacheResult) Success();
    }

    /**
     * Install the given package into the SystemCache
     */
    CacheResult install(string pkgID, scope Reader reader) @trusted
    {
        IndexPayload ip = reader.payload!IndexPayload;
        ContentPayload cp = reader.payload!ContentPayload;
        if (ip is null)
        {
            return cast(CacheResult) fail("Missing IndexPayload!");
        }
        if (cp is null)
        {
            return cast(CacheResult) fail("Missing ContentPayload!");
        }

        return installByDisk(pkgID, cp, ip, reader);
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

    /**
     * Full path for the hashed file
     */
    string fullPath(string hash) @safe
    {
        if (hash.length >= 10)
        {
            return installation.assetsPath("v2", hash[0 .. 2], hash[2 .. 4], hash[4 .. 6], hash);
        }
        return installation.assetsPath("v2", hash);
    }

private:

    /**
     * Install using copy_file_range for files on the disk.
     *
     * This is our low memory strategy
     */
    CacheResult installByDisk(string pkgID, scope ContentPayload cp, scope IndexPayload ip, scope Reader reader) @trusted
    {
        /* tmpfs must be avoided otherwise we'll kill RAM */
        string contentPath = installation.cachePath("content", pkgID);
        scope (exit)
        {
            import std.file : remove;

            contentPath.remove();
        }

        reader.unpackContent(cp, contentPath);
        auto content = File(contentPath, "rb");
        scope (exit)
        {
            content.close();
        }

        auto err = db.update((scope tx) @trusted {
            foreach (idx; ip)
            {
                string cacheID = idx.digestString();

                /* Check if we have this already */
                CacheEntry lookup;
                auto errLookup = lookup.load(tx, cacheID);
                if (errLookup.isNull)
                {
                    continue;
                }

                /* Splice the file */
                auto err = spliceFile(content, cacheID, idx);
                if (!err.isNull)
                {
                    return DatabaseResult(DatabaseError(DatabaseErrorCode.UncaughtException,
                        cast(string) err.get.toString));
                }

                lookup.id = cacheID;
                lookup.refCount = 0;
                auto errCopy = lookup.save(tx);
                if (!errCopy.isNull)
                {
                    return errCopy;
                }
            }
            return NoDatabaseError;
        });

        return err.isNull ? cast(CacheResult) Success() : cast(CacheResult) fail(err.message);
    }

    Nullable!(CError, CError.init) spliceFile(scope const ref File content,
            string cachePath, IndexEntry idx) @trusted
    {
        immutable string splicedPath = fullPath(cachePath);
        immutable splicedTree = splicedPath.dirName;
        splicedTree.mkdirRecurse;

        auto op = File(splicedPath, "wb");
        scope (exit)
        {
            op.close();
        }
        return IOUtil.copyFileRange(content.fileno, idx.start, op.fileno, 0,
                idx.contentSize).match!((bool b) {
            return Nullable!(CError, CError.init)(CError.init);
        }, (CError e) { return Nullable!(CError, CError.init)(e); });
    }

    Installation installation;
    Database db;
    string contentPath;
}
