/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.storage.db.statedb.state
 *
 * A State object encapsulates the system state (set of Selections) at a
 * given point in time.
 *
 * State objects are used to control transition from the current system
 * state to a new system state.
*
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.storage.db.statedb.state;

public import std.stdint : uint64_t;
public import moss.storage.db.statedb.selection;
import std.algorithm : map;
public import std.typecons : Nullable;

/**
 * Associate each state with a unique incrementing ID
 */
public alias StateID = uint64_t;

/**
 * Any future state is automatically assigned the value 0, so that it can be
 * correctly computed before StateDB saves to the underlying RocksDB.
 */
public immutable(StateID) futureState = 0;

/**
 * A State object encapsulates the system state (Selections) at a given point
 * in time, and can be created manually or automatically through transactions.
 * The State may have some associated metadata and is used to control transition
 * from the current system state to a new target state.
 *
 * Note that unlike conventional package managers this encapsulated state requires
 * no mutation to attain the final outcome, instead we apply each state as if it
 * were the root state (deduplication farming)
 */
public final class State
{

    /**
     * Return the ID for this state. 0 is assumed to be a target state
     */
    pragma(inline, true) pure @property StateID id() @safe @nogc nothrow const
    {
        return _id;
    }

    /**
     * Return the name of this state
     */
    pragma(inline, true) pure @property string name() @safe @nogc nothrow const
    {
        return _name;
    }

    /**
     * Return a description of this state
     */
    pragma(inline, true) pure @property string description() @safe @nogc nothrow const
    {
        return _description;
    }

    /**
     * Mark a selection with the given reason
     */
    void markSelection(in string pkgID, in SelectionReason reason) @safe
    {
        _selections[pkgID] = reason;
    }

    /**
     * Unmark (remove) a selection from this State
     */
    void unmarkSelection(in string pkgID) @safe
    {
        if (pkgID in _selections)
        {
            _selections.remove(pkgID);
        }
    }

    /**
     * Return the selections as immutable(Selection) range
     */
    pure @property auto selections() @trusted const
    {
        return _selections.keys.map!((k) => cast(immutable(Selection)) Selection(k, _selections[k]));
    }

    /**
     * Access a Selection type for the given pkgID. The return will be isNull()
     * if it doesn't exist.
     */
    pure @property NullableSelection selection(in string pkgid) @safe const
    {
        auto query = pkgid in _selections;
        if (query !is null)
        {
            return NullableSelection(Selection(pkgid, *query));
        }

        return NullableSelection();
    }

package:

    /**
     * Update the stateID
     */
    pure @property void id(in StateID id) @safe @nogc nothrow
    {
        _id = id;
    }

    /**
     * Update the name
     */
    pure @property void name(in string nom) @safe @nogc nothrow
    {
        _name = nom;
    }

    /**
     * Update the description
     */
    pure @property void description(in string desc) @safe @nogc nothrow
    {
        _description = desc;
    }

private:

    StateID _id = futureState;
    string _name = null;
    string _description = null;

    /**
     * Store our selections in an associative array
     */
    SelectionReason[string] _selections;
}
