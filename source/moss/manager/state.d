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

module moss.manager.state;

import moss.manager : StateManager;
public import std.stdint : uint64_t;
public import moss.manager.transaction : Transaction;
import std.exception : enforce;

/**
 * A State may be created with a specific purpose..
 */
public final enum StateType
{
    /** Automatic snapshot as created by the system */
    Regular = 0,

    /** Manually created by the user as a rollback point */
    Snapshot,

    /** Transient (not yet applied) state */
    Transient,
}

/**
 * A State is a view of a current or future installation state within the
 * target system.
 */
public final class State
{

    @disable this();

    /**
     * Return the ID property
     */
    pragma(inline, true) pure @property uint64_t id() @safe @nogc nothrow
    {
        return _id;
    }

    /**
     * Return the aliased name for this State
     */
    pragma(inline, true) pure @property string aliasName() @safe @nogc nothrow
    {
        return _aliasedName;
    }

    /**
     * Return the description for this State
     */
    pragma(inline, true) pure @property string description() @safe @nogc nothrow
    {
        return _description;
    }

    /**
     * Return underlying timestamp for the State
     */
    pragma(inline, true) pure @property uint64_t timestamp() @safe @nogc nothrow
    {
        return _time;
    }

    /**
     * Return the type of State
     */
    pragma(inline, true) pure @property StateType type() @safe @nogc nothrow
    {
        return _type;
    }

    /**
     * Return reference to the responsible Manager object
     */
    pragma(inline, true) pure @property StateManager manager() @safe @nogc nothrow
    {
        return _manager;
    }

    /**
     * Create a new Transaction from this base State
     */
    Transaction beginTransaction() @safe
    {
        return new Transaction(this);
    }

package:

    /**
     * Construct a new State with the given Manager as owning instance
     */
    this(StateManager manager, uint64_t id = 0) @safe
    {
        enforce(manager !is null, "State(): Cannot have null manager");
        _manager = manager;
        this.id = id;
    }

    /**
     * Update the ID property
     */
    pure @property void id(uint64_t id) @safe @nogc nothrow
    {
        _id = id;
    }

    /**
     * Update the aliased name for this State
     */
    pure @property void aliasName(const(string) aliasName) @safe @nogc nothrow
    {
        _aliasedName = aliasName;
    }

    /**
     * Update the description for this state
     */
    pure @property void description(const(string) desc) @safe @nogc nothrow
    {
        _description = desc;
    }

    /**
     * Update the State's internal timestamp
     */
    pure @property void timestamp(uint64_t time) @safe @nogc nothrow
    {
        _time = time;
    }

    /**
     * Update the State's type
     */
    pure @property void type(StateType type) @safe @nogc nothrow
    {
        _type = type;
    }

private:

    StateManager _manager;
    uint64_t _id = 0;
    uint64_t _time = 0;
    string _aliasedName = null;
    string _description = null;
    StateType _type = StateType.Regular;
}
