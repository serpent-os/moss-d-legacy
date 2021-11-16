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

module moss.storage.db.statedb;

import moss.context;
import moss.db;
import moss.db.rocksdb;
import std.stdint : uint64_t;

/**
 * Reason for a target being specified
 */
enum SelectionReason
{
    ManuallyInstalled = 0,
}

/**
 * A Selection is specially encoded to have a reason for selection, etc.
 */
struct Selection
{
    /**
     * Target (packageID) of this selection
     */
    const(string) target = null;

    /**
     * Reason for selection
     */
    SelectionReason reason = SelectionReason.ManuallyInstalled;

    /**
     * For now just encode the reason as target is in the key
     */
    ImmutableDatum mossdbEncode()
    {
        return reason.mossdbEncode();
    }

    /**
     * Just decode reason
     */
    void mossdbDecode(in ImmutableDatum rawBytes)
    {
        reason.mossdbDecode(rawBytes);
    }
}

/**
 * State simply wraps some metadata around the identifier number, descriptions,
 * etc.
 */
struct State
{
    /** Unique State identifier */
    uint64_t id = 0;

    /** Display name for state */
    string name = null;

    /** Some description for archival purposes */
    string description = null;
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
        const auto path = context().paths.db.buildPath("stateDB");
        db = new RDBDatabase(path, DatabaseMutability.ReadWrite);

        lastCreatedState = oldStateID();
    }

    /**
     * Return the last created state
     */
    State lastState()
    {
        return state(lastCreatedState);
    }

    /**
     * Return a state for the given ID
     */
    State state(uint64_t id)
    {
        if (id == 0)
        {
            return State(id, null, null);
        }
        return state(metadataBucket(id));
    }

    /**
     * Get the correct next state ID
     */
    uint64_t nextStateID()
    {
        return lastCreatedState + 1;
    }

    /**
     * Set the state bucket up
     */
    void addState(State st)
    {
        auto bucket = db.bucket(metadataBucket(st.id));
        bucket.set("stateID", st.id);
        if (st.name !is null)
        {
            bucket.set("name", st.name);
        }
        if (st.description !is null)
        {
            bucket.set("description", st.description);
        }

        /* Now the last created state.. */
        db.set("lastStateID", st.id);
        lastCreatedState = st.id;

        /* Reference the state ID to the metadata bucket for iteration */
        db.bucket("states").set(st.id, metadataBucket(st.id));
    }

    /**
     * Eventually serialise a struct as a value
     */
    void markSelection(uint64_t stateID, Selection selection)
    {
        auto bucket = db.bucket(selectionBucket(stateID));
        bucket.set(selection.target, selection);
    }

    /**
     * Return all selections within the given StateID
     */
    auto entries(uint64_t stateID)
    {
        import std.algorithm : map;

        auto bucket = db.bucket(selectionBucket(stateID));
        return bucket.iterator().map!((t) => {
            string keyName = null;
            keyName.mossdbDecode(cast(ImmutableDatum) t.entry.key);
            Selection selection = Selection(cast(string) keyName.dup());
            selection.mossdbDecode(cast(ImmutableDatum) t.value);
            return selection;
        }());
    }

    /**
     * Return all known States from the DB. Ill advised to copy the
     * returned range due to memory constraint
     */
    auto states()
    {
        import std.algorithm : map;

        return db.bucket("states").iterator().map!((t) => {
            string bucketID = null;
            bucketID.mossdbDecode(cast(ImmutableDatum) t.value);
            return this.state(bucketID);
        }());
    }

private:

    State state(const(string) sourceBucket)
    {
        import std.exception : enforce;

        auto bucket = db.bucket(sourceBucket);
        auto idRes = bucket.get!uint64_t("stateID");
        enforce(idRes.found, "Invalid state stored in DB without an ID");

        string description = null;
        string name = null;

        const auto descRes = bucket.get!string("description");
        if (descRes.found)
        {
            description = descRes.value;
        }

        const auto nameRes = bucket.get!string("name");
        if (nameRes.found)
        {
            name = nameRes.value;
        }

        return State(idRes.value, name, description);
    }

    Database db = null;

    /**
     * Return the selection bucket ID for the given release number
     */
    pragma(inline, true) const(string) selectionBucket(uint64_t stateID)
    {
        import std.string : format;

        return "selections.%d".format(stateID);
    }

    /**
     * Returns name for the root bucket
     */
    pragma(inline, true) const(string) metadataBucket(uint64_t stateID)
    {
        import std.string : format;

        return "metadata.%d".format(stateID);
    }

    /**
     * Return the old state ID if set
     */
    uint64_t oldStateID()
    {
        auto result = db.get!uint64_t("lastStateID");
        if (result.found)
        {
            return result.value;
        }
        return 0;
    }

    uint64_t lastCreatedState = 0;
}
