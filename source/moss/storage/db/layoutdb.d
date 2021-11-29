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
        const auto path = context().paths.db.buildPath("layoutDB");
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
