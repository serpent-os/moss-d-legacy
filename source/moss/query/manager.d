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

module moss.query.manager;

import serpent.ecs;

/**
 * The QueryManager is a centralisation point within moss to permit loading
 * "Hot" packages into the runtime system, and query those packages for potential
 * update paths, name resolution, dependencies, etc.
 *
 * At present this is a huge WIP to bolt name resolution into moss, but will ofc
 * be extended in time.
 */
public final class QueryManager
{

    /**
     * Construct a new QueryManager and initialise the runtime
     * system.
     */
    this()
    {
        entityManager = new EntityManager();
        entityManager.build();
    }

    /**
     * Close any EntityManager resources before associated DBs are
     * cleared from memory
     */
    void close()
    {
        entityManager.clear();
    }

private:

    EntityManager entityManager;
}
