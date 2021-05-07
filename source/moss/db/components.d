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

module moss.db.components;

public import serpent.ecs : serpentComponent;
public import std.stdint : uint64_t;

/**
 * Assign a timestamp (seconds since epoch) to an entity
 */
@serpentComponent public struct TimestampComponent
{
    uint64_t timestamp = 0;
}

/**
 * Simple component to assign a name to an entity
 */
@serpentComponent public struct NameComponent
{
    string name = null;
}

/**
 * Simple component to assign a description to an entity
 */
@serpentComponent public struct DescriptionComponent
{
    string description = null;
}
