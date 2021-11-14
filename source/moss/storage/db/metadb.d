/*
 * This file is part of moss.
 *
 * Copyright © 2020-2021 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module moss.storage.db.metadb;

import moss.db;
import moss.db.rocksdb;
import moss.deps;
import moss.format.binary.payload.meta;
import std.exception : enforce;
import std.string : format;
import std.conv : to;

/**
 * Per package metadata lives in ".meta.pkgID" namespace
 */
private static immutable auto perPackageMeta = ".meta";

/**
 * Per package dependencies live in ".deps.pkgID" namespace
 */
private static immutable auto perPackageDeps = ".deps";

/**
 * Per package providers live in ".provs.pkgID" namespace
 */
private static immutable auto perPackageProvs = ".provs";

/**
 * MetaDB is used as a storage mechanism for the MetaPayload within the
 * binary packages and repository index files. Internally it relies on RocksDB
 * via moss-db for all KV storage.
 */
public final class MetaDB
{
    @disable this();

    /**
     * Construct a new MetaDB with the absolute database path
     */
    this(in string dbPath)
    {
        db = new RDBDatabase(dbPath, DatabaseMutability.ReadWrite);
    }

    /**
     * Users of MetaDB should always explicitly close it to ensure
     * correct order of destruction for owned references.
     */
    void close()
    {
        if (db is null)
        {
            return;
        }
        db.close();
        db = null;
    }

    /**
     * Install metadata for this given payload. It will become referenced
     * by the internal pkgID of the payload.
     */
    void install(scope MetaPayload payload)
    {
        immutable auto pkgID = payload.getPkgID();
        enforce(pkgID !is null, "MetaDB.install(): Unable to obtain pkgID");

        auto pkgBucket = db.bucket("%s.%s".format(perPackageMeta, pkgID));
        auto depBucket = db.bucket("%s.%s".format(perPackageDeps, pkgID));
        auto provBucket = db.bucket("%s.%s".format(perPackageProvs, pkgID));

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
                dbSetter!string(pair.type, pair.tag, pair.get!string);
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
    }

private:

    /**
     * Add a provider to the package-private providers set
     */
    void addPackageProvider(scope IReadWritable bucket, in Provider provider)
    {

    }

    /**
     * Add a provider to the global provider set referencing this package
     */
    void addGlobalProvider(in string pkgID, in Provider provider)
    {

    }

    /**
     * Add a dependency to the package-private dependency set
     */
    void addPackageDependency(scope IReadWritable bucket, in Dependency dependency)
    {

    }

    Database db = null;
}
