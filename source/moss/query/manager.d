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
import moss.query.components;
import moss.context;

public import moss.query.source;

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
        /* PackageCandidate */
        context.entityManager.registerComponent!IDComponent;
        context.entityManager.registerComponent!NameComponent;
        context.entityManager.registerComponent!VersionComponent;
        context.entityManager.registerComponent!ReleaseComponent;

        context.entityManager.build();
        context.entityManager.step();
    }

    /**
     * Add a source to the QueryManager
     */
    void addSource(QuerySource source)
    {
        sources ~= source;
    }

    /**
     * Remove an existing source from this manager
     */
    void removeSource(QuerySource source)
    {
        import std.algorithm : remove;

        sources = sources.remove!((s) => s == source);
    }

    /**
     * Attempt to load the ID into our runtime
     */
    void loadID(const(string) pkgID)
    {
        import std.algorithm : each;

        auto v = View!ReadWrite(context.entityManager);

        sources.each!((s) => {
            auto qRes = s.queryID(pkgID);
            if (!qRes.found)
            {
                return;
            }
            auto entity = v.createEntity();
            v.addComponent(entity, IDComponent(qRes.candidate.id));
            v.addComponent(entity, NameComponent(qRes.candidate.name));
            v.addComponent(entity, VersionComponent(qRes.candidate.versionID));
            v.addComponent(entity, ReleaseComponent(qRes.candidate.release));
        }());
    }

    /**
     * Return all PackageCandidates by Name
     */
    auto byName(const(string) pkgName)
    {
        import std.algorithm : filter, map;

        auto view = View!ReadOnly(context.entityManager);
        return view.withComponents!(IDComponent, NameComponent,
                VersionComponent, ReleaseComponent)
            .filter!((tup) => tup[2].name == pkgName)
            .map!((tup) => PackageCandidate(tup[1].id, tup[2].name,
                    tup[3].versionID, tup[4].release));
    }

    /**
     * Sync all writes for reading
     */
    void update()
    {
        context.entityManager.step();
    }

private:

    EntityManager entityManager;
    QuerySource[] sources;
}
