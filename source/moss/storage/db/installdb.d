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

module moss.storage.db.installdb;

import moss.context;
import moss.db;
import moss.db.rocksdb;
import moss.format.binary.payload.meta;
import std.stdint : uint64_t;
import std.string : format;
import std.exception : enforce;

public import moss.query.source;

/**
 * InstallDB tracks packages installed across various states and doesn't specifically
 * link them to any given state. Instead it retains MetaData for locally installed
 * candidates to provide a system level of resolution for packages no longer referenced
 * from a repository.
 */
public final class InstallDB : QuerySource
{
    /**
     * Construct a new InstallDB which will immediately force a reload of the
     * on-disk database if it exists
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
        const auto path = context().paths.db.buildPath("installDB");
        db = new RDBDatabase(path, DatabaseMutability.ReadWrite);
    }

    /**
     * Install the given payload into our system. It is keyed by the
     * unique pkgID, so we can only retain a single payload per pkgID
     * and increase/decrease refcount as appropriate.
     */
    string installPayload(MetaPayload payload)
    {
        auto pkgID = getPkgID(payload);
        enforce(pkgID !is null, "installPayload(): Unable to get pkgID");

        auto metabucket = db.bucket(metadataBucket(pkgID));

        const auto result = db.bucket("index").get!string(pkgID);
        if (result.found)
        {
            /* Already stored this asset. */
            return pkgID;
        }

        /* Store this in the index now */
        db.bucket("index").set(pkgID, metadataBucket(pkgID));

        void joinRecord(V)(const(string) keyName, RecordType expType, RecordType realType, in V value)
        {
            enforce(expType == realType,
                    "installPayload(): Type should be %s, not %s".format(expType, realType));
            metabucket.set(keyName, value);
        }

        /* Walk through and retrieve all supported values */
        foreach (record; payload)
        {
            switch (record.tag)
            {
            case RecordTag.Architecture:
                joinRecord("architecture",
                        RecordType.String, record.type, record.val_string);
                break;
            case RecordTag.BuildRelease:
                joinRecord("buildRelease",
                        RecordType.Uint64, record.type, record.val_u64);
                break;
            case RecordTag.Description:
                joinRecord("description",
                        RecordType.String, record.type, record.val_string);
                break;
            case RecordTag.Homepage:
                joinRecord("homepage", RecordType.String,
                        record.type, record.val_string);
                break;
            case RecordTag.Name:
                joinRecord("name", RecordType.String,
                        record.type, record.val_string);
                break;
            case RecordTag.Release:
                joinRecord("release", RecordType.Uint64,
                        record.type, record.val_u64);
                break;
            case RecordTag.Summary:
                joinRecord("summary", RecordType.String,
                        record.type, record.val_string);
                break;
            case RecordTag.SourceID:
                joinRecord("sourceID", RecordType.String,
                        record.type, record.val_string);
                break;
            case RecordTag.Version:
                joinRecord("version", RecordType.String,
                        record.type, record.val_string);
                break;
            case RecordTag.Unknown:
            default:
                break;
            }
        }

        /* When we know the pkg will be definitely used, bump to 1. Start at 0 */
        setRefCount(pkgID, 0);
        return pkgID;
    }

    /**
     * Search our local DB for a match to the pkgID
     */
    QueryResult queryID(const(string) pkgID)
    {
        auto bucketID = db.bucket("index").get!string(pkgID);

        /* No bucket, no findy. */
        if (!bucketID.found)
        {
            return QueryResult(PackageCandidate.init, false);
        }

        /* Cache the bucket now */
        auto pkgBucket = db.bucket(bucketID.value);

        /* Absolutely require minimum values */
        auto nameRes = pkgBucket.get!string("name");
        enforce(nameRes.found, "queryID(): Local db corruption");
        auto versionRes = pkgBucket.get!string("version");
        enforce(versionRes.found, "queryID(): Local db corruption");
        auto releaseRes = pkgBucket.get!uint64_t("release");
        enforce(releaseRes.found, "queryID(): Local db corruption");

        /* Ensure the candidate goes back now */
        auto candidate = PackageCandidate(pkgID, nameRes.value.dup,
                versionRes.value.dup, releaseRes.value);
        return QueryResult(candidate, true);
    }

private:

    /** 
     * Return the full pkgID for a given meta payload
     */
    string getPkgID(MetaPayload payload)
    {
        import std.algorithm : each;

        string pkgName = null;
        uint64_t pkgRelease = 0;
        string pkgVersion = null;
        string pkgArchitecture = null;

        payload.each!((t) => {
            switch (t.tag)
            {
            case RecordTag.Name:
                pkgName = t.val_string;
                break;
            case RecordTag.Release:
                pkgRelease = t.val_u64;
                break;
            case RecordTag.Version:
                pkgVersion = t.val_string;
                break;
            case RecordTag.Architecture:
                pkgArchitecture = t.val_string;
                break;
            default:
                break;
            }
        }());

        enforce(pkgName !is null, "getPkgID(): Missing Name field");
        enforce(pkgVersion !is null, "getPkgID(): Missing Version field");
        enforce(pkgArchitecture !is null, "getPkgID(): Missing Architecture field");

        return "%s-%s-%d.%s".format(pkgName, pkgVersion, pkgRelease, pkgArchitecture);
    }

    /**
     * Set an explicit refCount for the pkgID
     */
    void setRefCount(const(string) pkgID, uint64_t refCount)
    {
        db.bucket(metadataBucket(pkgID)).set("refCount", refCount);
    }

    /**
     * Get current refcount for the pkg
     */
    uint64_t getRefCount(const(string) pkgID)
    {
        auto result = db.bucket(metadataBucket(pkgID)).get!uint64_t(pkgID);
        if (!result.found)
        {
            return 0;
        }

        return result.value;
    }

    /**
     * Return the per package metadata bucket name
     */
    pragma(inline, true) string metadataBucket(const(string) pkgID)
    {
        return "metadata.%s".format(pkgID);
    }

    Database db = null;
}
