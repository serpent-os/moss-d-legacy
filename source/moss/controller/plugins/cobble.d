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

module moss.controller.plugins.cobble;

public import moss.deps.registry;

import std.array : array;
import std.algorithm : filter, map;
import moss.format.binary.reader;
import moss.format.binary.payload.meta;
import std.stdio : File;

/**
 * The CobblePlugin provides a temporary source to emulate a repository of local
 * .stone archives as passed from "moss install" CLI to allow full integration
 * of side-loaded stone archives.
 */
public final class CobblePlugin : RegistryPlugin
{
    /**
     * Provide matching facilities for the local set of stones
     * Currently this is limited solely to PkgID + Name matching but we will
     * have to tie in providers too like LibraryName, etc, for dependency
     * solving to function.
     */
    override RegistryItem[] queryProviders(in ProviderType type, in string matcher)
    {
        switch (type)
        {
        case ProviderType.PackageName:
            return candidates.values
                .filter!((p) => p.name == matcher)
                .map!((r) => RegistryItem(r.id, this))
                .array();
        default:
            return [];
        }
    }

    /**
     * Provide details on a singular package
     */
    override Nullable!RegistryItem queryID(in string pkgID)
    {
        Nullable!RegistryItem item = Nullable!RegistryItem(RegistryItem.init);

        auto match = pkgID in candidates;
        if (match !is null)
        {
            item = RegistryItem(match.id, this);
        }

        return item;
    }

    /**
     * TODO: Implement dependencies
     */
    override const(Dependency)[] dependencies(in string pkgID) const
    {
        return null;
    }

    /**
     * TODO: Implement providers
     */
    override const(Provider)[] providers(in string pkgID) const
    {
        return null;
    }

    /**
     * Load a package into our store
     */
    void load(in string path)
    {
        auto fp = File(path, "rb");
        auto reader = new Reader(fp);

        /* Extract the metapayload */
        auto metaPayload = reader.payload!MetaPayload();

        scope (exit)
        {
            reader.close();
        }

        auto candidate = PackageCandidate();
        immutable auto id = metaPayload.getPkgID();

        foreach (record; metaPayload)
        {
            switch (record.tag)
            {
            case RecordTag.Name:
                candidate.name = record.get!string;
                break;
            case RecordTag.Release:
                candidate.release = record.get!uint64_t;
                break;
            case RecordTag.Version:
                candidate.versionID = record.get!string;
                break;
            default:
                break;
            }
        }
        candidate.id = id;
        candidates[id] = candidate;
    }

    /**
     * Return the package IDs loaded (successfully) into this CobblePlugin to allow
     * use with states.
     */
    auto pkgIDs()
    {
        return candidates.keys;
    }

private:

    PackageCandidate[string] candidates;
}
