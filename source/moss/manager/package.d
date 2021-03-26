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

/**
 * The moss.Manager module contains types that make it possible to interact
 * with the package mangling side of things.
 */
module moss.manager;

import serpent.ecs;
import std.stdint : uint64_t;

/**
 * Assign a Package ID to every package in the state
 */
@serpentComponent package struct PackageIDComponent
{
    string id;
}

/**
 * Assign a State ID component to every package in the state.
 */
@serpentComponent package struct StateIDComponent
{
    uint64_t stateID;
}

/**
 * The StateManager class the main entry point to package management operations,
 * allowing us to query and manipulate the state of an installed system.
 */
final class StateManager
{

public:

    /**
     * Construct a new moss StateManager
     */
    this()
    {
        _entity = new EntityManager();
        _entity.registerComponent!PackageIDComponent;
        _entity.registerComponent!StateIDComponent;
        _entity.build();
    }

    ~this()
    {
        _entity.clear();
    }

private:

    EntityManager _entity;
}
