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

module moss.db.state;

public import moss.db.state.entries;
public import moss.db.state.meta;
public import std.stdint : uint64_t;

import moss.format.binary.endianness;

/**
 * Internally a StateKey is used to automatically handle a state ID within
 * the KvPair derived databases
 */
public struct StateKey
{
    /** The State's unique ID */
    @AutoEndian uint64_t id = 0;
}

/* Future sanity */
static assert(StateKey.sizeof == 8, "StateKey.sizeof should be exactly 8 bytes");
