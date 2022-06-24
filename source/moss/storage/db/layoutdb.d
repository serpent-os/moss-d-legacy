/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.storage.db.layoutdb
 *
 * The LayoutDB stores the Layout of .stone packages via a pkgID
 * and permits subsequent queries.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.storage.db.layoutdb;

import moss.context;
import moss.db;
import moss.db.rocksdb;
import moss.format.binary.payload.layout;
import moss.core.encoding;

/**
 * The LayoutDB is responsible for storing a package's Layout via a pkgID,
 * and permitting subsequent queries.
 */
public final class LayoutDB
{
    /**
     * Construct a new LayoutDB which will immediately force a reload of the
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
        const auto path = join([context().paths.db, "layoutDB"], "/");
        db = new RDBDatabase(path, DatabaseMutability.ReadWrite);
    }

    /**
     * Begin installation of the payload to the DB
     */
    void installPayload(const(string) pkgID, LayoutPayload payload)
    {
        foreach (es; payload)
        {
            db.bucket(pkgID).set(es.target, es);
        }
    }

    /**
     * Return an automatic range for all of our EntrySets within a pkgID
     * bucket.
     *
     * Essentially converts all records for the package ID into runtime usable
     * structs for introspection.
     */
    auto entries(const(string) pkgID)
    {
        import std.algorithm : map;

        return db.bucket(pkgID).iterator().map!((t) => {
            EntrySet es = void;
            es.mossDecode(cast(ImmutableDatum) t.value);
            return es;
        }());
    }

private:

    Database db = null;
}
