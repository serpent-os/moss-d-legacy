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

package:

    /**
     * Construct a new State with the given Manager as owning instance
     */
    this(StateManager _manager, uint64_t id = 0)
    {
        _manager = _manager;
        this.id = id;
    }

    /**
     * Update the ID property
     */
    pure @property void id(uint64_t id) @safe @nogc nothrow
    {
        _id = id;
    }

private:

    StateManager _manager;
    uint64_t _id = 0;
}
