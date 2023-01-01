/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.statedb
 *
 * State Database
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.client.statedb;

import moss.client.installation;
import moss.db.keyvalue;
import moss.db.keyvalue.errors;
import moss.db.keyvalue.interfaces;
import moss.db.keyvalue.orm;
import registry = moss.deps.registry;
import std.algorithm : map;
import std.array : array;
import std.datetime;
import std.datetime.systime;
import std.exception : enforce;
import std.experimental.logger;
import std.file : exists;

public import std.stdint : uint8_t, uint64_t;
public import moss.core.errors;
import std.string : format;

/**
 * Each state has a unique numerical identifier
 */
public alias StateID = uint64_t;

/**
 * Most states are automatically constructed
 */
public enum StateType : uint8_t
{
    /**
     * Automatically constructed state
     */
    Transaction = 0,
}

/**
 * A potential system state (model)
 */
@Model public struct State
{
    /**
     * Unique identifier for this state
     */
    @PrimaryKey @AutoIncrement StateID id;

    /**
     * Quick summary for the state (optional)
     */
    string summary;

    /**
     * Description for the state (optional)
     */
    string description;

    /**
     * Package IDs / selections in this state
     */
    string[] pkgIDs;

    /**
     * Creation timestamp
     */
    uint64_t tsCreated;

    /**
     * Relevant type for this State
     */
    StateType type = StateType.Transaction;
}

public alias StateResult = Optional!(Success, Failure);

/**
 * Manages our State entries
 */
public final class StateDB
{
    @disable this();

package:

    /**
     * Construct a new StateDB from the given install
     */
    this(Installation install) @safe
    {
        this.installation = install;
    }

    /**
     * Attempt to connect
     */
    StateResult connect() @safe
    {
        immutable dbPath = installation.dbPath("state");
        tracef("StateDB: %s", dbPath);
        auto flags = installation.mutability == Mutability.ReadWrite
            ? DatabaseFlags.CreateIfNotExists : DatabaseFlags.ReadOnly;

        /* We have no DB. */
        if (!dbPath.exists && installation.mutability == Mutability.ReadOnly)
        {
            return cast(StateResult) fail(format!"StateDB: Cannot find %s"(dbPath));
        }

        Database.open("lmdb://" ~ dbPath, flags).match!((Database db) {
            this.db = db;
        }, (DatabaseError err) { throw new Exception(err.message); });

        if (installation.mutability == Mutability.ReadWrite)
        {
            immutable err = db.update((scope tx) => tx.createModel!(State));
            if (!err.isNull)
            {
                return cast(StateResult) fail(err.message);
            }
        }
        return cast(StateResult) Success();
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
     * Create a new state from the input registry items
     */
    State createState(registry.Transaction tx, in registry.RegistryItem[] items) @safe
    {
        State st = State(0);
        auto now = Clock.currTime(UTC());
        /* TODO: Improve! */
        st.summary = "Automatically generated state";
        st.description = "Automatically generated state";
        st.tsCreated = now.toUnixTime();
        st.type = StateType.Transaction;

        /* TODO: Record automatic deps! */
        st.pkgIDs = () @trusted {
            return cast(string[]) items.map!((p) => p.pkgID).array;
        }();

        return st;
    }

    /**
     * Save a populated State
     */
    StateResult save(ref State st) @safe
    {
        immutable err = db.update((scope tx) @safe {
            State lookup;
            /* Disallow overwrite */
            immutable lookupErr = lookup.load(tx, st.id);
            if (lookupErr.isNull)
            {
                return DatabaseResult(DatabaseError(DatabaseErrorCode.BucketExists,
                    "Trying to overwrite existing state"));
            }
            return st.save(tx);
        });
        if (!err.isNull)
        {
            return cast(StateResult) fail(err.get.message);
        }
        return cast(StateResult) Success();
    }

    /**
     * Return the selections in the given StateID
     */
    auto selections(StateID id) @safe
    {
        State st;
        db.view((in tx) => st.load(tx, id));
        return st.pkgIDs;
    }

private:

    Database db;
    Installation installation;
}
