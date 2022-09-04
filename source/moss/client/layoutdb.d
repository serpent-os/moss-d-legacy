/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.layoutdb
 *
 * Layout Database
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.layoutdb;

import moss.client.installation;
import moss.db.keyvalue;
import moss.db.keyvalue.errors;
import moss.db.keyvalue.interfaces;
import moss.db.keyvalue.orm;
import std.exception : enforce;
import std.experimental.logger;
import std.file : exists;
import std.string : format;
import std.array : array;
public import moss.format.binary.reader;
public import moss.format.binary.payload.layout;

public import moss.core.errors;

public alias LayoutResult = Optional!(Success, Failure);

/**
 * A Layout is keyed by a unique package ID and
 * contains all entries
 */
public @Model struct Layout
{
    /**
     * Unique package ID
     */
    @PrimaryKey string pkgID;

    /**
     * Entries for the filesystem
     */
    EntrySet[] entries;
}

/**
 * Manages our Layout entries
 */
public final class LayoutDB
{
    @disable this();

package:

    /**
     * Construct a new LayoutDB from the given install
     */
    this(Installation install) @safe
    {
        this.installation = install;
    }

    /**
     * Attempt to connect
     */
    LayoutResult connect() @safe
    {
        immutable dbPath = installation.dbPath("layout");
        tracef("LayoutDB: %s", dbPath);
        auto flags = installation.mutability == Mutability.ReadWrite
            ? DatabaseFlags.CreateIfNotExists : DatabaseFlags.ReadOnly;

        /* We have no DB. */
        if (!dbPath.exists && installation.mutability == Mutability.ReadOnly)
        {
            return cast(LayoutResult) fail(format!"LayoutDB: Cannot find %s"(dbPath));
        }

        Database.open("lmdb://" ~ dbPath, flags).match!((Database db) {
            this.db = db;
        }, (DatabaseError err) { throw new Exception(err.message); });

        if (installation.mutability == Mutability.ReadWrite)
        {
            immutable err = db.update((scope tx) => tx.createModel!(Layout));
            if (!err.isNull)
            {
                return cast(LayoutResult) fail(err.message);
            }
        }
        return cast(LayoutResult) Success();
    }

    /**
     * Close the DB handles
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
     * Store a single LayoutPayload in the DB
     */
    LayoutResult install(string pkgID, scope Reader r) @safe
    {
        LayoutPayload lp = () @trusted { return r.payload!LayoutPayload; }();
        if (lp is null)
        {
            return cast(LayoutResult) fail("Missing LayoutPayload");
        }
        Layout lt = Layout(pkgID);
        lt.entries = lp.array;
        immutable err = db.update((scope tx) => lt.save(tx));
        if (!err.isNull)
        {
            return cast(LayoutResult) fail(err.message);
        }
        return cast(LayoutResult) Success();
    }

private:

    Database db;
    Installation installation;
}
