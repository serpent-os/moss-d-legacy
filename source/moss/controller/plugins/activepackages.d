/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.controller.plugins.activepackages
 *
 * The ActivePackages plugin is responsible for knowing which packages
 * are installed in the current state.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.controller.plugins.activepackages;

public import moss.deps.registry;

import moss.storage.db.packagesdb;
import moss.storage.db.statedb;

import std.algorithm : map, filter;
import std.array : array;

/**
 * The active packages plugin uses a State to know what is currently installed
 * by simply filtering the SystemPackagesDB using the current state object
 * prior to mutation.
 */
public final class ActivePackagesPlugin : RegistryPlugin
{

    @disable this();

    /**
     * Construct a new ActivePackagesPlugin using the provided package
     * and state DB.
     */
    this(SystemPackagesDB packageDB, StateDB stateDB)
    {
        this.packageDB = packageDB;
        this.stateDB = stateDB;
        installedState = cast(State) stateDB.state(stateDB.activeState);
    }

    /**
     * Return any matching providers, filtering for installed only
     */
    override RegistryItem[] queryProviders(in ProviderType type, in string matcher,
            ItemFlags flags = ItemFlags.None)
    {
        /* We only support installed */
        if (flags != ItemFlags.None && (flags & ItemFlags.Installed) != ItemFlags.Installed)
        {
            return null;
        }

        /**
         * Ensure we only look at our own providers and not the system wide set
         */
        bool installationFilter(in string p)
        {
            if (installedState !is null)
            {
                return !installedState.selection(p).isNull();
            }
            return false;
        }

        return packageDB.byProvider(type, matcher).filter!(installationFilter)
            .map!((id) => RegistryItem(id, this, ItemFlags.Installed))
            .array();
    }

    /**
     * Provide details on a singular package
     */
    override NullableRegistryItem queryID(in string pkgID) const
    {
        if (installedState !is null && !installedState.selection(pkgID)
                .isNull() && packageDB.hasID(pkgID))
        {
            return NullableRegistryItem(RegistryItem(pkgID,
                    cast(RegistryPlugin) this, ItemFlags.Installed));
        }
        return NullableRegistryItem();
    }

    /**
     * Return the dependencies for the given pkgID
     */
    override const(Dependency)[] dependencies(in string pkgID) const
    {
        return packageDB.dependencies(pkgID).array();
    }

    /**
     * Return the providers for the given pkgID
     */
    override const(Provider)[] providers(in string pkgID) const
    {
        return packageDB.providers(pkgID).array();
    }

    /**
     * Retrieve info for the package
     */
    override ItemInfo info(in string pkgID) const
    {
        return packageDB.info(pkgID);
    }

    /**
     * Retrieve listing of items in this plugin
     */
    override const(RegistryItem)[] list(in ItemFlags flags) const
    {
        /* Got no state :( */
        if (installedState is null)
        {
            return null;
        }

        /* Only allow listing by Installed. */
        if (flags != ItemFlags.None && (flags & ItemFlags.Installed) != ItemFlags.Installed)
        {
            return null;
        }

        return installedState.selections
            .filter!((s) => packageDB.hasID(s.target))
            .map!((s) => RegistryItem(s.target, cast(RegistryPlugin) this, ItemFlags.Installed))
            .array();
    }

    /**
     * Do nothing, no resources here.
     */
    override void close()
    {
    }

    /**
     * No-op
     */
    override void fetchItem(FetchContext context, in string pkgID)
    {
    }

private:

    SystemPackagesDB packageDB = null;
    StateDB stateDB = null;
    State installedState = null;
}
