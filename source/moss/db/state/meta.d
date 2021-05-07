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
public import serpent.ecs;

import moss.format.binary.payload.kvpair;
import moss.context;
import moss.db.components;
import std.meta : AliasSeq;

/**
 * Currently supported state meta payload version
 */
const uint16_t stateMetaPayloadVersion = 1;

alias StateMetaArchetype = AliasSeq!(MetaPrimaryKey, TimestampComponent,
        NameComponent, DescriptionComponent);

/**
 * Our primary key simply contains the ID
 */
@serpentComponent public struct MetaPrimaryKey
{
    /** Numerical ID of the state */
    uint64_t id = 0;

    /** Type of state */
    StateType type = StateType.Invalid;
}

/**
 * Specific type of State being stored
 */
public enum StateType : uint8_t
{
    /**
     * Unusable
     */
    Invalid = 0,

    /**
     * Moss automatically triggered this State
     */
    MossTriggered = 1,

    /**
     * The user explicitly triggered this State
     */
    UserTriggered = 2,

    /**
     * The user explicitly created a backup
     */
    UserBackup = 3,
}

/**
 * The StateDescriptor is used to describe a State within the meta table,
 * giving it optional kind, description, etc.
 */
public struct StateDescriptor
{
    /**
     * Unique ID for the State
     */
    uint64_t id = 0;

    /**
     * Display name for the State
     */
    string name = null;

    /**
     * Archival description for the State
     */
    string description = null;

    /**
     * What *kind* of State this is
     */
    StateType type = StateType.Invalid;

    /**
     * UNIX timestamp for State creation
     */
    uint64_t timestamp = 0;
}

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
        entityManager.tryRegisterComponent!MetaPrimaryKey;
        filePath = context.paths.db.buildPath("state.meta");
    }

    /**
     * Return a newly prepared payload
     */
    override KvPairPayload preparePayload()
    {
        return new StateMetaPayload();
    }

    /**
     * All entities with the MetaPrimaryKey component will be purged from the
     * ECS tables
     */
    override void clear()
    {
        dropEntitiesWithComponents!MetaPrimaryKey();
    }

    /**
     * Add a State to the DB if it doesn't already exist
     */
    void addState(StateDescriptor st)
    {
        import std.exception : enforce;

        enforce(st.type != StateType.Invalid, "StateMetaDB.addState(): Cannot add .Invalid state");

        auto view = View!ReadWrite(entityManager);
        auto ent = view.createEntityWithComponents!StateMetaArchetype;
        view.addComponent(ent, MetaPrimaryKey(st.id));
        view.addComponent(ent, TimestampComponent(st.timestamp));
        view.addComponent(ent, NameComponent(st.name));
        view.addComponent(ent, DescriptionComponent(st.description));
    }

    /**
     * Return a new range containing all State descriptors
     */
    auto states()
    {
        import std.algorithm : map;

        auto view = View!ReadOnly(entityManager);
        return view.withComponents!StateMetaArchetype
            .map!((t) => StateDescriptor(t[1].id, t[3].name, t[4].description,
                    t[1].type, t[2].timestamp));
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

    /**
     * No-op right now, need to store records on disk from the StateMetaDB ECS components
     */
    override void writeRecords(void delegate(scope ubyte[] key, scope ubyte[] value) rwr)
    {
        import std.algorithm : each;

        /* TODO: Actually emit the encoded value! */
        void writeOne(ref StateDescriptor sd)
        {
            import moss.db.state : StateKey;
            import moss.format.binary.endianness : toNetworkOrder;
            import std.stdio : writefln;

            StateKey keyEnc = StateKey(sd.id);
            keyEnc.toNetworkOrder();
            auto keyz = (cast(ubyte*)&keyEnc)[0 .. keyEnc.sizeof];
            rwr(keyz, keyz);

            writeln(sd);
        }

        auto db = cast(StateMetaDB) userData;
        db.states.each!((s) => writeOne(s));
    }

    /**
     * No-op right now, need to load records into the StateMetaDB ECS components from disk
     */
    override void loadRecord(scope ubyte[] key, scope ubyte[] data)
    {
        import moss.db.state : StateKey;
        import moss.format.binary.endianness : toHostOrder;
        import std.stdio : writeln;

        /* TODO: Actually decode the value! */
        StateKey* skey = cast(StateKey*) key;
        auto cp = *skey;
        cp.toHostOrder();
        writeln(cp);
    }
}
