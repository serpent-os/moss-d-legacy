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
import std.meta : AliasSeq;

import moss.db.components : NameComponent;

/**
 * Currently supported state entries payload version
 */
const uint16_t stateEntriesPayloadVersion = 1;

/**
 * Archetype for StateEntries records
 */
alias StateEntriesArchetype = AliasSeq!(EntryRelationalKey, NameComponent, SelectionComponent);

/**
 * A selection can be either binary or source, changing how we resolve
 * the selection
 */
public enum SelectionType : uint8_t
{
    Source = 0,
    Binary = 1,
}

/**
 * Each selection can have specific flags set on it which allow us to
 * understand whether something was explicitly installed (UserInstalled)
 * or appeared through use of the depsolver
 */
public enum SelectionFlags : uint32_t
{
    /** No custom policy is applied */
    DefaultPolicy = 1 << 0,

    /** The user explicitly installed this selection */
    UserInstalled = 1 << 1,

    /** Installed implicitly through the depsolver */
    DepInstalled = 1 << 2,

    /** Never seek an update for this package  */
    Hold = 1 << 3,

    /** Always prefer source for this package */
    PreferSource = 1 << 4,
}

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
 * Stores the selection information in the ECS
 */
@serpentComponent public struct SelectionComponent
{
    /**
     * The type of selection, i.e. binary, source
     */
    SelectionType type;

    /**
     * The flags on this selection
     */
    SelectionFlags flags;
}

/**
 * Accessible entry within the database
 */
public struct StateEntry
{
    /**
     * Identifier for the entry
     */
    string id = null;

    /**
     * State ID for the entry
     */
    uint64_t state = 0;

    /**
     * Type for the entry
     */
    SelectionType type = SelectionType.Binary;

    /**
     * Flags for the entry
     */
    SelectionFlags flags = SelectionFlags.DefaultPolicy;
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
        entityManager.tryRegisterComponent!SelectionComponent;
        filePath = context.paths.db.buildPath("state.entries.db");
    }

    /**
     * Mark a selection for identifier within stateID with the given selection information
     */
    void markSelection(uint64_t stateID, const(string) identifier,
            SelectionType type, SelectionFlags flags)
    {
        import std.algorithm : filter, map;

        auto view = View!ReadWrite(entityManager);

        /* Search for existing entities */
        auto matchingEntities = view.withComponents!StateEntriesArchetype
            .filter!((t) => t[1].stateID == stateID && t[2].name == identifier)
            .map!((t) => t[0].id);

        /* Update front match if found */
        if (!matchingEntities.empty)
        {
            auto ent = matchingEntities.front;
            SelectionComponent* sel = view.data!SelectionComponent(ent);
            sel.type = type;
            sel.flags = flags;
            return;
        }

        /* Construct new entity with the selection data */
        auto ent = view.createEntityWithComponents!StateEntriesArchetype;
        view.addComponent(ent, EntryRelationalKey(stateID));
        view.addComponent(ent, NameComponent(identifier));
        view.addComponent(ent, SelectionComponent(type, flags));
    }

    /**
     * Unmark the selection from the stateID so it is then forgotten
     */
    void unmarkSelection(uint64_t stateID, const(string) identifier)
    {
        import std.algorithm : each, filter, map;

        auto view = View!ReadWrite(entityManager);
        view.withComponents!StateEntriesArchetype
            .filter!((t) => t[1].stateID == stateID && t[2].name == identifier)
            .map!((t) => t[0].id)
            .each!((id) => view.killEntity(id));
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

    /**
     * Return a range for all entries in the ECS
     */
    auto entries()
    {
        import std.algorithm : map;

        return View!ReadOnly(entityManager).withComponents!StateEntriesArchetype
            .map!((t) => StateEntry(t[2].name, t[1].stateID, t[3].type, t[3].flags));
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
