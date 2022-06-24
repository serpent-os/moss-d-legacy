/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.storage.db.metadb
 *
 * MetaDB is a storage mechanism for the MetaPayload stored within binary
 * .stone packages and moss index repositories.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.storage.db.metadb;

import moss.db;
import moss.db.rocksdb;
import moss.deps;
import moss.core.encoding;
import moss.format.binary.payload.meta;
import std.exception : enforce;
import std.string : format;
import std.conv : to;
import std.algorithm : map;

/**
 * Ensure sane (centralised) bucket naming
 */
private static enum BucketName : string
{
    PackageMeta = ".meta",
    PackageDependencies = ".deps",
    PackageProviders = ".provs",
    GlobalProviders = "provs",
}

/**
 * MetaDB is used as a storage mechanism for the MetaPayload within the
 * binary packages and repository index files. Internally it relies on RocksDB
 * via moss-db for all KV storage.
 */
public class MetaDB
{
    @disable this();

    /**
     * Construct a new MetaDB with the absolute database path
     */
    this(in string dbPath)
    {
        this.dbPath = dbPath;
        reloadDB();
    }

    /**
     * Request a full reload of the database
     */
    final void reloadDB()
    {
        close();
        _db = new RDBDatabase(dbPath, DatabaseMutability.ReadWrite);
        indexBucket = db.bucket("index");
    }

    /**
     * Users of MetaDB should always explicitly close it to ensure
     * correct order of destruction for owned references.
     */
    final void close()
    {
        if (db is null)
        {
            return;
        }
        db.close();
        _db = null;
        indexBucket = null;
    }

    /**
     * Install metadata for this given payload. It will become referenced
     * by the internal pkgID of the payload.
     */
    final void install(scope MetaPayload payload)
    {
        immutable auto pkgID = payload.getPkgID();
        enforce(pkgID !is null, "MetaDB.install(): Unable to obtain pkgID");

        auto pkgBucket = db.bucket("%s.%s".format(BucketName.PackageMeta, pkgID));
        auto depBucket = db.bucket("%s.%s".format(BucketName.PackageDependencies, pkgID));
        auto provBucket = db.bucket("%s.%s".format(BucketName.PackageProviders, pkgID));

        void dbSetter(T)(in RecordType type, in RecordTag tag, in T data)
        {
            immutable auto keyname = tag.to!string;
            pkgBucket.set(keyname, data);
        }

        foreach (ref pair; payload)
        {
            /* Dispatch correct handling */
            final switch (pair.type)
            {
            case RecordType.Uint8:
                dbSetter!uint8_t(pair.type, pair.tag, pair.get!uint8_t);
                break;
            case RecordType.Int8:
                dbSetter!int8_t(pair.type, pair.tag, pair.get!int8_t);
                break;
            case RecordType.Uint16:
                dbSetter!uint16_t(pair.type, pair.tag, pair.get!uint16_t);
                break;
            case RecordType.Int16:
                dbSetter!int16_t(pair.type, pair.tag, pair.get!int16_t);
                break;
            case RecordType.Uint32:
                dbSetter!uint32_t(pair.type, pair.tag, pair.get!uint32_t);
                break;
            case RecordType.Int32:
                dbSetter!int32_t(pair.type, pair.tag, pair.get!int32_t);
                break;
            case RecordType.Uint64:
                dbSetter!uint64_t(pair.type, pair.tag, pair.get!uint64_t);
                break;
            case RecordType.Int64:
                dbSetter!int64_t(pair.type, pair.tag, pair.get!int64_t);
                break;
            case RecordType.String:
                auto sz = pair.get!string;

                /* Record virtual provider for the name in the DB */
                if (pair.tag == RecordTag.Name)
                {
                    auto prov = Provider(sz, ProviderType.PackageName);
                    addGlobalProvider(pkgID, prov);
                    addPackageProvider(provBucket, prov);
                }

                dbSetter!string(pair.type, pair.tag, sz);
                break;
            case RecordType.Provider:
                enforce(pair.tag == RecordTag.Provides);
                immutable auto provider = pair.get!Provider;
                addPackageProvider(provBucket, provider);
                addGlobalProvider(pkgID, provider);
                break;
            case RecordType.Dependency:
                enforce(pair.tag == RecordTag.Depends);
                addPackageDependency(depBucket, pair.get!Dependency);
                break;
            case RecordType.Unknown:
                break;
            }
        }

        /* Mark this package as existing in the index for quicker queries
         * and to permit iterations. We don't care about the value here
         * but the DB needs one.
         */
        indexBucket.set(pkgID, 1);
    }

    /**
     * Intended for integration with moss-deps RegistryPlugin, simply return
     * true if this pkgID exists
     */
    final bool hasID(in string pkgID) const
    {
        auto ibucket = cast(IReadWritable) indexBucket;
        auto result = ibucket.get!int(pkgID);
        return result.found;
    }

    /**
     * Return all dependencies for a given pkgID
     */
    final auto dependencies(in string pkgID) const
    {
        auto idb = cast(Database) _db;

        IReadWritable depBucket = idb.bucket("%s.%s".format(BucketName.PackageDependencies, pkgID));
        return depBucket.iterator().map!((i) => {
            Dependency d = Dependency.init;
            d.mossDecode(cast(ImmutableDatum) i.entry.key);
            return cast(const(Dependency)) d;
        }());
    }

    /**
     * Return all providers for a given pkgID
     */
    final auto providers(in string pkgID) const
    {
        auto idb = cast(Database) _db;
        IReadWritable provBucket = idb.bucket("%s.%s".format(BucketName.PackageProviders, pkgID));
        return provBucket.iterator().map!((i) => {
            Provider p = Provider.init;
            p.mossDecode(cast(ImmutableDatum) i.entry.key);
            return cast(const(Provider)) p;
        }());
    }

    /**
     * Return a range of (string) pkgIDs matchin the input string specification
     * and provider type
     */
    final auto byProvider(in ProviderType type, in string specification)
    {
        auto bucket = db.bucket("%s.%s.%s".format(BucketName.GlobalProviders,
                type.to!string, specification));

        return bucket.iterator().map!((p) => {
            string s = null;
            s.mossDecode(cast(ImmutableDatum) p.entry.key);
            return s;
        }());
    }

    /**
     * Return the information on the package
     */
    final ItemInfo info(in string pkgID) const
    {
        auto cdb = cast(Database) _db;

        string name = null;
        string summary = null;
        string description = null;
        uint64_t release = 0;
        string versionID = null;

        auto bucket = cdb.bucket("%s.%s".format(BucketName.PackageMeta, pkgID));
        void getValue(T)(T* storage, RecordTag tag)
        {
            auto result = bucket.get!T(tag.to!string);
            enforce(result.found);
            *storage = result.value;
        }

        getValue(&name, RecordTag.Name);
        getValue(&summary, RecordTag.Summary);
        getValue(&description, RecordTag.Description);
        getValue(&release, RecordTag.Release);
        getValue(&versionID, RecordTag.Version);

        return ItemInfo(name, summary, description, release, versionID);
    }

    /**
     * Return a string range of pkgid within this DB
     */
    final auto list() const
    {
        auto ibucket = cast(IReadWritable) indexBucket;
        return ibucket.iterator().map!((i) {
            string pkgID;
            pkgID.mossDecode(cast(ImmutableDatum) i.entry.key);
            return pkgID;
        });
    }

    /**
     * Safely return a value from the metadata payload if it exists, otherwise
     * the return value will return true with isNull()
     */
    Nullable!(T, T.init) getValue(T)(in string pkgID, RecordTag tag)
    {
        auto bucket = db.bucket(format!"%s.%s"(BucketName.PackageMeta, pkgID));
        auto result = bucket.get!T(tag.to!string);
        if (result.found)
        {
            return Nullable!(T, T.init)(result.value);
        }
        return Nullable!(T, T.init)(T.init);
    }

protected:

    /**
     * Allow subclasses to directly access the underlying database
     */
    pragma(inline, true) pure final @property Database db() @safe @nogc nothrow
    {
        return _db;
    }

private:

    /**
     * Add a provider to the package-private providers set
     */
    pragma(inline, true) void addPackageProvider(scope IReadWritable bucket, in Provider provider)
    {
        /* Value required, we only care for key, set value as 1 */
        bucket.set(provider, 1);
    }

    /**
     * Add a provider to the global provider set referencing this package
     */
    pragma(inline, true) void addGlobalProvider(in string pkgID, in Provider provider)
    {
        auto bucket = db.bucket("%s.%s.%s".format(BucketName.GlobalProviders,
                provider.type.to!string, provider.target));
        bucket.set(pkgID, provider);
    }

    /**
     * Add a dependency to the package-private dependency set
     */
    pragma(inline, true) void addPackageDependency(scope IReadWritable bucket,
            in Dependency dependency)
    {
        /* Value required, we only care for key, set value as 1 */
        bucket.set(dependency, 1);
    }

    Database _db = null;
    IReadWritable indexBucket = null;
    string dbPath = null;
}
