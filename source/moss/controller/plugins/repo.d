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

module moss.controller.plugins.repo;

public import moss.deps.registry;

import moss.storage.db.metadb;
import moss.format.binary.reader;
import moss.format.binary.payload.meta;
import std.algorithm : map;
import std.exception : enforce;
import std.array;
import moss.context;
import moss.storage.cachepool;
import std.path : dirName;

/**
 * The repo plugin encapsulates access to online software repositories providing
 * the means to search for software , and install a full chain of met dependencies.
 */
public final class RepoPlugin : RegistryPlugin
{

    @disable this();

    /**
     * Construct a new RepoPlugin with the given ID
     */
    this(CachePool pool, in string id, in string indexURI)
    {
        this._id = id;
        this._pool = pool;
        this._indexURI = indexURI;
        this._indexBase = indexURI.dirName;
        auto dbPath = context.paths.db.buildPath("repo", _id);
        metaDB = new MetaDB(dbPath);
    }

    /**
     * Return the ID for this RepoPlugin
     */
    pragma(inline, true) pure @property string id() @safe @nogc nothrow const
    {
        return _id;
    }

    /**
     * Return any matching providers
     */
    override RegistryItem[] queryProviders(in ProviderType type, in string matcher,
            ItemFlags flags = ItemFlags.None)
    {
        /* Only return available items */
        if (flags != ItemFlags.None && (flags & ItemFlags.Available) != ItemFlags.Available)
        {
            return null;
        }

        return metaDB.byProvider(type, matcher).map!((i) => RegistryItem(i,
                this, ItemFlags.Available)).array();
    }

    /**
     * Provide details on a singular package
     */
    override NullableRegistryItem queryID(in string pkgID) const
    {
        if (metaDB.hasID(pkgID))
        {
            return NullableRegistryItem(RegistryItem(pkgID,
                    cast(RegistryPlugin) this, ItemFlags.Available));
        }
        return NullableRegistryItem();
    }

    /**
     * Return the dependencies for the given pkgID
     */
    override const(Dependency)[] dependencies(in string pkgID) const
    {
        return metaDB.dependencies(pkgID).array();
    }

    /**
     * Return the providers for the given pkgID
     */
    override const(Provider)[] providers(in string pkgID) const
    {
        return metaDB.providers(pkgID).array();
    }

    /**
     * Return  info for the package
     */
    override ItemInfo info(in string pkgID) const
    {
        if (metaDB.hasID(pkgID))
        {
            return metaDB.info(pkgID);
        }
        return ItemInfo();
    }

    /**
     * List all known pkgIDs within the MetaDB
     */
    override const(RegistryItem)[] list(in ItemFlags flags) const
    {
        /* Only list available items */
        if (flags != ItemFlags.None && (flags & ItemFlags.Available) != ItemFlags.Available)
        {
            return null;
        }

        return metaDB.list().map!((p) => RegistryItem(p, cast(RepoPlugin) this,
                ItemFlags.Available)).array();
    }

    /**
     * Free up assets we have, i.e. the DB
     */
    override void close()
    {
        if (metaDB is null)
        {
            return;
        }
        metaDB.close();
        metaDB.destroy();
        metaDB = null;
    }

    /**
     * No-op
     */
    override void fetchItem(FetchContext context, in string pkgID)
    {
    }

private:

    /**
     * Reload the index into the DB
     */
    void reloadIndex()
    {
        auto fi = File(indexLocal, "rb");
        auto rdr = new Reader(fi);
        scope (exit)
        {
            rdr.close();
        }

        /* Make sure this is actually a repo */
        enforce(rdr.archiveHeader.type == MossFileType.Repository, "Unsupported repository index");

        /* Insert every payload in */
        foreach (hdr; rdr.headers)
        {
            if (hdr.type != PayloadType.Meta)
            {
                continue;
            }
            auto meta = cast(MetaPayload) hdr.payload;
            metaDB.install(meta);
        }
    }

    MetaDB metaDB = null;
    string indexLocal = null;
    string _id = null;
    string _indexURI = null;
    string _indexBase = null;
    CachePool _pool = null;
}
