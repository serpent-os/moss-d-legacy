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

module moss.db.state.entries;

public import moss.db : MossDB;
public import serpent.ecs;
public import moss.format.binary.payload.kvpair;

import moss.format.binary.endianness;
import std.stdint : uint64_t;
import moss.context;

/**
 * Currently supported state entries payload version
 */
const uint16_t stateEntriesPayloadVersion = 1;

/**
 * The EntryRelationalKey maps each entry in the StateEntriesDB to a state
 * identifier specified in the StateMetaDB
 */
@serpentComponent public struct EntryRelationalKey
{
    /** Unique ID for the corresponding state */
    @AutoEndian uint64_t stateID = 0;
}

/**
 * The StateEntriesDB is used to store each selection in a given state as
 * recorded within the StateMetaDB
 */
public final class StateEntriesDB : MossDB
{
    @disable this();

    /**
     * Construct a new StateEntriesDB using the given EntityManager
     */
    this(EntityManager entityManager)
    {
        super(entityManager);
        entityManager.tryRegisterComponent!EntryRelationalKey;
        filePath = context.paths.db.buildPath("state.entries");
    }

    /**
     * Return a newly prepared payload
     */
    override KvPairPayload preparePayload()
    {
        return new StateEntriesPayload();
    }

    /**
     * All entities with the EntryRelationalKey component will be purged from the
     * ECS tables
     */
    override void clear()
    {
        dropEntitiesWithComponents!EntryRelationalKey();
    }
}
/**
 * The StateEntriesPayload is a specialised KvPairPayload that handles
 * encoding/decoding of the StateEntriesDB to and from a moss archive
 */
public final class StateEntriesPayload : KvPairPayload
{

    /**
     * Construct a new CachePayload
     */
    this()
    {
        super(PayloadType.StateEntriesDB, stateEntriesPayloadVersion);
    }

    static this()
    {
        import moss.format.binary.reader : Reader;

        Reader.registerPayloadType!StateEntriesPayload(PayloadType.StateEntriesDB);
    }

    /**
     * No-op right now, need to store records on disk from the StatEntriesDB ECS components
     */
    override void writeRecords(void delegate(scope ubyte[] key, scope ubyte[] value) rwr)
    {
    }

    /**
     * No-op right now, need to load records into the StateEntriesDB ECS components from disk
     */
    override void loadRecord(scope ubyte[] key, scope ubyte[] data)
    {
    }
}
