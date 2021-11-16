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
 * State simply wraps some metadata around the identifier number, descriptions,
 * etc.
 */
public struct State
{
    /** Unique State identifier */
    StateID id = 0;

    /** Display name for state */
    string name = null;

    /** Some description for archival purposes */
    string description = null;
}
