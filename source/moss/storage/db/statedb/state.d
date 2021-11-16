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

module moss.storage.db.statedb.state;

public import std.stdint : uint64_t;

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

private:

    StateID _id = futureState;
    string _name = null;
    string _description = null;
}
