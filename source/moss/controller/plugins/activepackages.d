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
     * TODO: Support getting info for the package
     */
    override ItemInfo info(in string pkgID) const
    {
        return packageDB.info(pkgID);
    }

    /**
     * TODO: Support listing items in this plugin
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

private:

    SystemPackagesDB packageDB = null;
    StateDB stateDB = null;
    State installedState = null;
}
