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

import std.algorithm : map;
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

        return packageDB.byProvider(type, matcher)
            .map!((id) => RegistryItem(id, this, ItemFlags.Installed)).array();
    }

    /**
     * Provide details on a singular package
     */
    override Nullable!RegistryItem queryID(in string pkgID)
    {
        Nullable!RegistryItem item = Nullable!RegistryItem(RegistryItem.init);

        return item;
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
    override Nullable!ItemInfo info(in string pkgID) const
    {
        throw new Error("ActivePackagesPlugin.info(): Not yet implemented");
    }

    /**
     * TODO: Support listing items in this plugin
     */
    override const(RegistryItem)[] list(in ItemFlags flags) const
    {
        /* Only allow listing by Installed. */
        if (flags != ItemFlags.None && (flags & ItemFlags.Installed) != ItemFlags.Installed)
        {
            return null;
        }
        return null;
    }

private:

    SystemPackagesDB packageDB = null;
    StateDB stateDB = null;
    State installedState = null;
}
