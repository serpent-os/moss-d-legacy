/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.storage.db.statedb
 *
 * The StateDB is used to record current system state.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.storage.db.statedb;

import moss.context;
import moss.core.encoding;
import moss.db;
import moss.db.rocksdb;
import std.stdint : uint64_t;
import std.string : format;
import std.algorithm : each;

public import moss.storage.db.statedb.selection;
public import moss.storage.db.statedb.state;

/**
 * Ensure sane namespacing of buckets
 */
private static enum BucketName : string
{
    BookKeeping = "bookKeeping",
    Index = "index",
    SelectionEntries = ".entries",
    SelectionMeta = ".meta",
}

/**
 * Ensure sane keys
 */
private static enum KeyName : string
{
    LastAllocatedState = "lastAllocatedID",
    CurrentState = "currentState",
    MetaName = "name",
    MetaDescription = "description",
}

/**
 * The StateDB allows us to record system states within the database for
 * future mutation and current blits
 */
final class StateDB
{

    /** 
     * Construct a new StateDB, immediately reload it
     */
    this()
    {
        reloadDB();
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
        const auto path = join([context().paths.db, "stateDB"], "/");
        db = new RDBDatabase(path, DatabaseMutability.ReadWrite);

        updateBookKeeping();
        indexBucket = db.bucket(cast(string) BucketName.Index);
    }

    /**
     * Return a state for a previously allocated ID
     */
    immutable(State) state(in StateID id) @trusted
    {
        immutable auto queryExists = indexBucket.get!int(id);
        if (!queryExists.found)
        {
            return null;
        }

        auto newState = new State();
        newState.id = id;
        auto metaBucket = db.bucket("%s.%s".format(BucketName.SelectionMeta, id));

        /* Grab basic props */
        auto queryName = metaBucket.get!string(cast(string) KeyName.MetaName);
        auto queryDescription = metaBucket.get!string(cast(string) KeyName.MetaDescription);

        if (queryName.found)
        {
            newState.name = queryName.value;
        }

        if (queryDescription.found)
        {
            newState.description = queryName.value;
        }

        /* Grab all entries */
        auto entryBucket = db.bucket("%s.%s".format(BucketName.SelectionEntries, id));
        entryBucket.iterator().each!((k, v) => {
            string target = null;
            SelectionReason reason = SelectionReason.ManuallyInstalled;
            target.mossDecode(cast(ImmutableDatum) k.key);
            reason.mossDecode(cast(ImmutableDatum) v);
            newState.markSelection(target, reason);
        }());

        return cast(immutable(State)) newState;
    }

    /**
     * Add a new State to the DB. This will not actually make it active!
     * It will however assign an ID to the State.
     */
    void addState(ref State newState)
    {
        auto bookBucket = db.bucket(cast(string) BucketName.BookKeeping);
        bookBucket.set(cast(string) KeyName.LastAllocatedState, futureID);

        /* Ensure we know our status.. */
        scope (exit)
        {
            updateBookKeeping();
        }

        newState.id = futureID;
        auto metaBucket = db.bucket("%s.%s".format(BucketName.SelectionMeta, newState.id));
        auto entryBucket = db.bucket("%s.%s".format(BucketName.SelectionEntries, newState.id));

        /* Establish this state in the index */
        indexBucket.set!(StateID, int)(newState.id, 1);

        /* Encode metadata */
        immutable auto name = newState.name;
        if (name !is null && name != "")
        {
            metaBucket.set(cast(string) KeyName.MetaName, name);
        }
        immutable auto desc = newState.description;
        if (desc !is null && desc != "")
        {
            metaBucket.set(cast(string) KeyName.MetaDescription, desc);
        }

        /* Encode all entries */
        foreach (selection; newState.selections)
        {
            entryBucket.set!(string, SelectionReason)(selection.target, selection.reason);
        }
    }

    /**
     * Set the active ID for going forwards
     */
    @property void activeState(in StateID id)
    {
        auto bookBucket = db.bucket(cast(string) BucketName.BookKeeping);
        bookBucket.set!(string, StateID)(cast(string) KeyName.CurrentState, id);
        updateBookKeeping();
    }

    /**
     * Return the active state ID
     */
    pure @property StateID activeState() @safe @nogc nothrow
    {
        return activeID;
    }

private:

    /**
     * Update last allocated ID
     */
    void updateBookKeeping()
    {
        lastAllocatedID = 0;
        activeID = 0;

        auto bucket = db.bucket(cast(string) BucketName.BookKeeping);
        auto queryLast = bucket.get!StateID(cast(string) KeyName.LastAllocatedState);
        auto queryActive = bucket.get!StateID(cast(string) KeyName.CurrentState);

        if (queryLast.found)
        {
            lastAllocatedID = queryLast.value;
        }

        if (queryActive.found)
        {
            activeID = queryActive.value;
        }

        /* Future ID is always newer than last, regardless of active */
        futureID = lastAllocatedID + 1;
    }

    Database db = null;
    StateID lastAllocatedID = 0;
    StateID activeID = 0;
    StateID futureID = 0;
    IReadWritable indexBucket = null;
}
