/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.activeplugin
 *
 * Implements a moss-deps plugin for packages considered 'installed'
 * within the currently active state.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.activeplugin;

public import moss.deps.registry;
public import moss.client.statedb;
public import moss.client.installation;
public import moss.client.installdb;

import std.algorithm : filter, map;
import std.array : array;

/**
 * ActivePlugin provides a filtered view of a MetaDB,
 * i.e. the InstallDB, to know what is currently installed
 * in the context of the current state.
 */
public final class ActivePlugin : RegistryPlugin
{
    @disable this();

    /**
     * Construct a new ActivePlugin for the given install
     */
    this(Installation installation, InstallDB installDB, StateDB stateDB) @safe
    {
        this.activeID = installation.activeState();
        this.installDB = installDB;
        this.stateDB = stateDB;

        if (activeID != 0)
        {
            /* Create simple mapping */
            foreach (id; stateDB.selections(activeID))
            {
                pkgIDs[id] = true;
            }
        }
        import std.experimental.logger : tracef;

        tracef("%s", pkgIDs);
    }

    /**
     * Examine MetaDB for matching providers
     */
    override RegistryItem[] queryProviders(in ProviderType type, in string matcher,
            ItemFlags flags = ItemFlags.None) @trusted
    {
        if ((flags & ItemFlags.Installed) != ItemFlags.Installed && flags != ItemFlags.None)
        {
            return null;
        }
        auto db = installDB.metaDB;
        return db.byProvider(type, matcher).filter!((pkgID) => (pkgID in pkgIDs) !is null)
            .map!((pkgID) => RegistryItem(pkgID, cast(RegistryPlugin) this, ItemFlags.Installed))
            .array();
    }

    /**
     * Get ItemInfo for specific pkgID
     */
    override ItemInfo info(in string pkgID) @trusted const
    {
        auto idb = cast(InstallDB) installDB;
        return idb.metaDB.info(pkgID);
    }

    /**
     * Query the pkgID in the database
     */
    override NullableRegistryItem queryID(in string pkgID) @safe
    {
        return NullableRegistryItem(NullableRegistryItem.init);
    }

    /**
     * Return dependencies for the given pkgID
     */
    override const(Dependency)[] dependencies(in string pkgID) @trusted const
    {
        auto idb = cast(InstallDB) installDB;
        auto entry = idb.metaDB.byID(pkgID);
        return entry.dependencies;
    }

    /**
     * Return providers for the given pkgID
     */
    override const(Provider)[] providers(in string pkgID) @trusted const
    {
        auto idb = cast(InstallDB) installDB;
        auto entry = idb.metaDB.byID(pkgID);
        return entry.providers;
    }

    /**
     * Retrive a list of all pkgs matching the given flags
     */
    override const(RegistryItem)[] list(in ItemFlags flags) @trusted const
    {
        if ((flags & ItemFlags.Installed) != ItemFlags.Installed && flags != ItemFlags.None)
        {
            return null;
        }

        auto idb = cast(InstallDB) installDB;
        return idb.metaDB.list().filter!((e) => (e.pkgID in pkgIDs) !is null)
            .map!((entry) {
                return RegistryItem(entry.pkgID, cast(RegistryPlugin) this, ItemFlags.Installed);
            })
            .array();

    }

    /**
     * noop
     */
    override Job fetchItem(in string pkgID) @safe
    {
        return null;
    }

    /**
     * Close any allocated resources
     */
    override void close() @safe
    {
    }

    override pure @property uint64_t priority() @safe @nogc nothrow const
    {
        return 0;
    }

private:

    InstallDB installDB;
    StateID activeID;
    StateDB stateDB;
    bool[string] pkgIDs;
}
