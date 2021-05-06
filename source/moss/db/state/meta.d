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

module moss.db.state.meta;

public import moss.db : MossDB;
public import serpent.ecs : EntityManager;

import moss.format.binary.payload.kvpair;
import std.path : buildPath;

/**
 * Currently supported state meta payload version
 */
const uint16_t stateMetaPayloadVersion = 1;

/**
 * The StateMetaDB is responsible for storing metadata on each state entry
 * within a permanent database file on disk. It is used in conjunction with
 * the StateEntriesDB to compute, store and analyse states.
 */
public final class StateMetaDB : MossDB
{
    @disable this();

    /**
     * Construct a new StateMetaDB using the given EntityManager
     */
    this(EntityManager entityManager)
    {
        super(entityManager);
        filePath = buildPath("/moss/db/state.meta");
    }
}

/**
 * The StateMetaPayload is a specialised KvPairPayload that handles
 * encoding/decoding of the StateMetaDB to and from a moss archive
 */
public final class StateMetaPayload : KvPairPayload
{

    /**
     * Construct a new CachePayload
     */
    this()
    {
        super(PayloadType.StateMetaDB, stateMetaPayloadVersion);
    }

    static this()
    {
        import moss.format.binary.reader : Reader;

        Reader.registerPayloadType!StateMetaPayload(PayloadType.StateMetaDB);
    }
}
