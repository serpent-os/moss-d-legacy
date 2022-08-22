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
import moss.client.installation : Mutability;
import moss.db.keyvalue;
import moss.db.keyvalue.errors;
import moss.db.keyvalue.interfaces;
import moss.db.keyvalue.orm;
import std.file : exists;
import std.experimental.logger;
import std.string : format;

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
    this(string dbPath, Mutability mut) @safe
    {
        this.dbPath = dbPath;
        this.mut = mut;
    }

    /**
     * Connect to the underlying storage
     *
     * Returns: Success or Failure
     */
    MetaResult connect() @safe
    {
        tracef("MetaDB: %s", dbPath);
        auto flags = mut == Mutability.ReadWrite
            ? DatabaseFlags.CreateIfNotExists : DatabaseFlags.ReadOnly;

        /* We have no DB. */
        if (!dbPath.exists && mut == Mutability.ReadOnly)
        {
            return cast(MetaResult) fail(format!"MetaDB: Cannot find %s"(dbPath));
        }

        Database.open("lmdb://" ~ dbPath, flags).match!((Database db) {
            this.db = db;
        }, (DatabaseError err) { throw new Exception(err.message); });

        return cast(MetaResult) Success();
    }

private:

    string dbPath;
    Mutability mut;
    Database db;
}
