/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.metadb
 *
 * Metadata DB
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.metadb;
import moss.core.errors;
import moss.db.keyvalue;
import moss.db.keyvalue.errors;
import moss.db.keyvalue.interfaces;
import moss.db.keyvalue.orm;
import std.file : exists;
import std.experimental.logger;
import std.string : format;

public import std.stdint : uint64_t;
public import moss.deps.dependency;
import moss.deps.registry : ItemInfo;
import moss.format.binary.payload.meta : MetaPayload, RecordTag, RecordType;

/**
 * Simple ORM to store backlinks for providers.
 */
@Model struct ProviderMap
{
    /**
     * Something along the lines of, pkgconfig(someName)
     */
    @PrimaryKey string identifier;

    /**
     * Package identifiers matching in the map
     */
    string[] pkgIDs;
}

/**
 * A MetaEntry is our ORM-specific storage of moss
 * metadata.
 */
@Model public struct MetaEntry
{
    /**
     * Primary key in the db *is* the package ID
     */
    @PrimaryKey string pkgID;

    /**
     * Package name
     */
    string name;

    /**
     * Human readable version identifier
     */
    string versionIdentifier;

    /**
     * Package release as set in stone.yml
     */
    uint64_t sourceRelease;

    /**
     * Build machinery specific build release
     */
    uint64_t buildRelease;

    /**
     * Architecture this was built for
     */
    string architecture;

    /**
     * Brief one line summary of the package
     */
    string summary;

    /**
     * Description of the package
     */
    string description;

    /**
     * The source-grouping ID
     */
    string sourceID;

    /** 
     * Where'd we find this guy..
     */
    string homepage;

    /**
     * Licenses this is available under
     */
    string[] licenses;

    /**
     * All dependencies
     */
    Dependency[] dependencies;

    /**
     * All providers, including name()
     */
    Provider[] providers;

    /**
     * If relevant: uri to fetch from
     */
    string uri;

    /**
     * If relevant: hash for the download
     */
    string hash;

    /**
     * How big is this package in the repo..?
     */
    uint64_t downloadSize;
}

/**
 * Either works or it doesn't :)
 */
public alias MetaResult = Optional!(Success, Failure);

/**
 * Metadata encapsulation within a DB.
 *
 * Used for storing system wide (installed) packages as well
 * as powering "remotes".
 */
public final class MetaDB
{
    @disable this();

    /**
     * Construct a new MetaDB from the given path
     */
    this(string dbPath, bool readWrite) @safe
    {
        this.dbPath = dbPath;
        this.readWrite = readWrite;
    }

    /**
     * Grab ItemInfo for the given pkg, which saves a lot
     * of effort for the plugins.
     */
    auto info(string pkgID) @safe
    {
        MetaEntry entry;
        immutable err = db.view((in tx) => entry.load(tx, pkgID));
        if (!err.isNull)
        {
            return ItemInfo.init;
        }
        immutable licenses = () @trusted {
            return cast(immutable(string[])) entry.licenses;
        }();
        return ItemInfo(entry.name, entry.summary, entry.description,
                entry.sourceRelease, entry.versionIdentifier, entry.homepage, licenses);
    }

    auto list() @safe
    {
        MetaEntry[] entries;

        db.view((in tx) @safe {
            foreach (ent; tx.list!MetaEntry())
            {
                entries ~= ent;
            }
            return NoDatabaseError;
        });
        return entries;
    }

    /**
     * Connect to the underlying storage
     *
     * Returns: Success or Failure
     */
    MetaResult connect(bool nosync = false) @safe
    {
        tracef("MetaDB: %s", dbPath);
        auto flags = readWrite ? DatabaseFlags.CreateIfNotExists : DatabaseFlags.ReadOnly;

        if (nosync)
        {
            flags |= DatabaseFlags.DisableSync;
        }

        /* We have no DB. */
        if (!dbPath.exists && !readWrite)
        {
            return cast(MetaResult) fail(format!"MetaDB: Cannot find %s"(dbPath));
        }

        Database.open("lmdb://" ~ dbPath, flags).match!((Database db) {
            this.db = db;
        }, (DatabaseError err) { throw new Exception(err.message); });

        /**
         * Ensure our DB model exists.
         */
        if (readWrite)
        {
            auto err = db.update((scope tx) => tx.createModel!(MetaEntry, ProviderMap));
            if (!err.isNull)
            {
                return cast(MetaResult) fail(err.message);
            }
        }

        return cast(MetaResult) Success();
    }

    /**
     * Load from the remote index file
     */
    MetaResult loadFromIndex(string indexFile) @safe
    {
        import moss.format.binary.reader : Reader;
        import moss.format.binary.payload.meta : MetaPayload, RecordTag, RecordType;
        import std.stdio : File;

        scope Reader reader = new Reader(File(indexFile, "rb"));
        scope (exit)
        {
            reader.close();
        }

        immutable wipe = db.update((scope tx) @safe {
            auto e1 = tx.removeAll!MetaEntry;
            if (!e1.isNull)
            {
                return e1;
            }
            return tx.removeAll!ProviderMap;
        });
        if (!wipe.isNull)
        {
            return cast(MetaResult) fail(wipe.message);
        }
        immutable rebuild = db.update((scope tx) => tx.createModel!(MetaEntry, ProviderMap));
        if (!rebuild.isNull)
        {
            return cast(MetaResult) fail(rebuild.message);
        }

        DatabaseResult updater(scope Transaction tx) @trusted
        {
            foreach (payload; reader.payloads!MetaPayload)
            {
                MetaPayload mp = cast(MetaPayload) payload;
                immutable e = insertPayload(tx, mp);
                if (!e.isNull)
                {
                    return e;
                }
            }
            return NoDatabaseError;
        }

        immutable err = db.update(&updater);
        if (err.isNull)
        {
            return cast(MetaResult) Success();
        }
        return cast(MetaResult) fail(err.message);
    }

    /**
     * Close the underlying connection
     */
    void close() @safe
    {
        if (db !is null)
        {
            db.close();
            db = null;
        }
    }

    /**
     * Find all pkgIDs matching the given provider query
     */
    auto byProvider(ProviderType providerType, string datum) @safe
    {
        immutable lookupName = Provider(datum, providerType).toString;
        ProviderMap lookup;
        immutable e = db.view((in tx) => lookup.load(tx, lookupName));
        if (!e.isNull)
        {
            return null;
        }
        return lookup.pkgIDs;
    }

    /**
     * Return the Nullable item
     */
    MetaEntry byID(string pkgID) @safe
    {
        MetaEntry lookup;
        immutable err = db.view((in tx) => lookup.load(tx, pkgID));
        if (err.isNull)
        {
            return lookup;
        }
        return MetaEntry.init;
    }

    /**
     * Install a single package directly
     *
     * Params:
     *      payload = The MetaPayload
     * Returns: Optional success or failure
     */
    MetaResult install(scope MetaPayload payload) @safe
    {
        immutable err = db.update((scope tx) => insertPayload(tx, payload));
        return err.isNull ? cast(MetaResult) Success() : cast(MetaResult) fail(err.message);
    }

private:

    /**
     * Insert all supported metapayload records into the transaction
     *
     * Params:
     *      tx = DB Transaction
     *      mp = MetaPayload
     * Returns: Nullable DatabaseError
     */
    DatabaseResult insertPayload(scope Transaction tx, scope MetaPayload mp) @trusted
    {
        MetaEntry entry;
        foreach (pair; mp)
        {
            final switch (pair.tag)
            {
            case RecordTag.Architecture:
                entry.architecture = pair.get!string;
                break;
            case RecordTag.BuildRelease:
                entry.buildRelease = pair.get!uint64_t;
                break;
            case RecordTag.Conflicts:
                /* Not yet supported */
                break;
            case RecordTag.Depends:
                entry.dependencies ~= pair.get!Dependency;
                break;
            case RecordTag.Description:
                entry.description = pair.get!string;
                break;
            case RecordTag.Homepage:
                entry.homepage = pair.get!string;
                break;
            case RecordTag.License:
                entry.licenses ~= pair.get!string;
                break;
            case RecordTag.Name:
                entry.name = pair.get!string;
                break;
            case RecordTag.PackageHash:
                entry.hash = pair.get!string;
                entry.pkgID = entry.hash;
                break;
            case RecordTag.PackageSize:
                entry.downloadSize = pair.get!uint64_t;
                break;
            case RecordTag.PackageURI:
                entry.uri = pair.get!string;
                break;
            case RecordTag.Provides:
                entry.providers ~= pair.get!Provider;
                break;
            case RecordTag.Release:
                entry.sourceRelease = pair.get!uint64_t;
                break;
            case RecordTag.SourceID:
                entry.sourceID = pair.get!string;
                break;
            case RecordTag.Summary:
                entry.summary = pair.get!string;
                break;
            case RecordTag.Unknown:
                /* derp */
                break;
            case RecordTag.Version:
                entry.versionIdentifier = pair.get!string;
                break;
            }
        }

        /* We need to store all the providers now.. */
        foreach (prov; entry.providers)
        {
            auto e = insertProvider(tx, entry.pkgID, prov);
            if (!e.isNull)
            {
                return e;
            }
        }

        /* Now store the name() provider. */
        auto e = insertProvider(tx, entry.pkgID, Provider(entry.name, ProviderType.PackageName));
        if (!e.isNull)
        {
            return e;
        }

        immutable eStore = entry.save(tx);
        if (!eStore.isNull)
        {
            return eStore;
        }
        return NoDatabaseError;
    }

    /**
     * Insert the provider into the global reverse mapping
     *
     * This permits a simplified reverse lookup table to very
     * quickly check the dependency providers.
     *
     * Params:
     *      tx = DB Transaction
     *      pkgID = Unique package identifier
     *      prov = The provider to insert
     * Returns: Nullable DatabaseError
     */
    DatabaseResult insertProvider(scope Transaction tx, string pkgID, Provider prov) @safe
    {
        auto bucketID = prov.toString();
        ProviderMap storage;
        immutable e = storage.load(tx, bucketID);
        if (!e.isNull && e.code != DatabaseErrorCode.BucketNotFound
                && e.code != DatabaseErrorCode.KeyNotFound)
        {
            return e;
        }
        storage.identifier = bucketID;
        storage.pkgIDs ~= pkgID;
        immutable e2 = storage.save(tx);
        if (!e2.isNull)
        {
            return e2;
        }
        return NoDatabaseError;
    }

    string dbPath;
    bool readWrite;
    Database db;
}
