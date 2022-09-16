/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cobbleplugin
 *
 * Cobbles stones together for a moss-deps plugin
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cobbleplugin;

public import moss.deps.registry;
public import moss.client.installation;

import moss.client.metadb;
import moss.core.errors;
import std.algorithm : map;
import std.array : array;
import std.sumtype;
import std.string : format;
import moss.core.ioutil;
import std.file : rmdirRecurse;
import std.experimental.logger;
import std.path : absolutePath;

import moss.core : computeSHA256;

import moss.format.binary.reader;
import moss.format.binary.payload.meta;

/**
 * We have to remember some additional info as
 * we're pretending to be a collection.
 */
private struct FetchInfo
{
    uint64_t expectedSize;
    string hash;
    string uri;
}

/**
 * Either a registry item - or a failure.
 */
public alias CobbleResult = Optional!(RegistryItem, Failure);

/**
 * Cobbler of local stones
 */
public final class CobblePlugin : RegistryPlugin
{

    /**
     * Construct a new CobblePlugin
     */
    this(Installation installation) @safe
    {
        this.installation = installation;
        () @trusted {
            IOUtil.createTemporaryDirectory("/tmp/moss-cobble-XXXXXX").match!((CError err) {
                throw new Error(cast(string) err.toString);
            }, (string s) { trace(format!"CobblePlugin: %s"(s)); dbPath = s; });
        }();

        db = new MetaDB(dbPath, installation.mutability == Mutability.ReadWrite);
        db.connect().match!((Success _) {}, (Failure f) {
            throw new Error(f.message);
        });
    }

    /**
     * Try to load the package and return a RegistryItem for it.
     */
    CobbleResult loadPackage(string filename) @trusted
    {
        auto f = File(filename, "rb");
        Reader reader = new Reader(f);
        scope (exit)
        {
            reader.close();
        }
        if (reader.fileType != MossFileType.Binary)
        {
            return cast(CobbleResult) fail("CobblePlugin.loadPackage(): Unsupported filetype");
        }
        MetaPayload mp = reader.payload!MetaPayload;
        if (mp is null)
        {
            return cast(CobbleResult) fail("CobblePlugin: Missing MetaPayload");
        }
        immutable hash = computeSHA256(filename, true);
        immutable uri = format!"file://%s"(filename.absolutePath);
        immutable expSize = f.size();
        immutable pkgID = hash;
        mp.addRecord(RecordType.String, RecordTag.PackageHash, hash);
        mp.addRecord(RecordType.String, RecordTag.PackageURI, uri);
        mp.addRecord(RecordType.String, RecordTag.PackageSize, expSize);
        return db.install(mp).match!((Failure f) { return cast(CobbleResult) f; }, (_) {
            return cast(CobbleResult) RegistryItem(pkgID, this, ItemFlags.Available);
        });
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
        download.remoteURI = item.uri;
        download.expectedSize = item.downloadSize;

        return download;
    }

    /**
     * Close any allocated resources
     */
    override void close() @safe
    {
        if (db is null)
        {
            return;
        }
        db.close();
        db = null;
        dbPath.rmdirRecurse();
    }

    override pure @property uint64_t priority() @safe @nogc nothrow const
    {
        return uint64_t.max;
    }

private:

    Installation installation;
    string dbPath;
    MetaDB db;
}
