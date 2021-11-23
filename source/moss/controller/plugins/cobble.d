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
import std.path : absolutePath;
import std.stdio : File;
import std.string : format;

private struct ProviderSet
{
    /* Map pkgID to Provider */
    Provider[string] providers;
}

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
    override RegistryItem[] queryProviders(in ProviderType type, in string matcher,
            ItemFlags flags = ItemFlags.None)
    {
        /* We only support available */
        if (flags != ItemFlags.None && (flags & ItemFlags.Available) != ItemFlags.Available)
        {
            return null;
        }
        immutable auto providerKey = format!"prov.%s.%s"(type, matcher);
        auto bucket = providerKey in globalProviders;
        if (bucket is null)
        {
            return null;
        }

        return bucket.providers.keys.map!((k) => RegistryItem(k, this,
                ItemFlags.Available)).array();
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
            item = RegistryItem(match.id, this, ItemFlags.Available);
        }

        return item;
    }

    /**
     * Return the dependencies for the given pkgID
     */
    override const(Dependency)[] dependencies(in string pkgID) const
    {
        auto match = pkgID in candidates;
        if (match is null)
        {
            return null;
        }
        return match.dependencies;
    }

    /**
     * Return the providers for the given pkgID
     */
    override const(Provider)[] providers(in string pkgID) const
    {
        auto match = pkgID in candidates;
        if (match is null)
        {
            return null;
        }
        return match.providers;
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
        filePaths[id] = path.absolutePath;

        foreach (record; metaPayload)
        {
            switch (record.tag)
            {
            case RecordTag.Name:
                auto name = record.get!string;
                candidate.name = name;

                /* Store virtual provider name */
                auto provName = Provider(name, ProviderType.PackageName);
                addGlobalProvider(id, provName);
                candidate.providers ~= provName;
                break;
            case RecordTag.Release:
                candidate.release = record.get!uint64_t;
                break;
            case RecordTag.Version:
                candidate.versionID = record.get!string;
                break;
            case RecordTag.Depends:
                candidate.dependencies ~= record.get!Dependency;
                break;
            case RecordTag.Provides:
                auto prov = record.get!Provider;
                candidate.providers ~= prov;
                addGlobalProvider(id, prov);
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
    auto items()
    {
        return candidates.keys.map!((c) => RegistryItem(c, this, ItemFlags.Available));
    }

    /**
     * TODO: Support fetching the asset
     */
    override void fetch(in string pkgID)
    {
        throw new Error("CobblePlugin.fetch(): Not yet implemented");
    }

    /**
     * TODO: Support installing the asset
     */
    override void install(in string pkgID)
    {
        throw new Error("CobblePlugin.install(): Not yet implemented");
    }

    /**
     * TODO: Support getting info for the package
     */
    override Nullable!ItemInfo info(in string pkgID) const
    {
        throw new Error("CobblePlugin.info(): Not yet implemented");
    }

    /**
     * TODO: Support listing items in this plugin
     */
    override const(RegistryItem)[] list(in ItemFlags flags) const
    {
        /* Only allow listing by Available. Not yet used */
        if (flags != ItemFlags.None && (flags & ItemFlags.Available) != ItemFlags.Available)
        {
            return null;
        }
        return null;
    }

private:

    /**
     * Stash provider in global lookup table to make it faster.
     */
    void addGlobalProvider(in string pkgID, in Provider provider)
    {
        immutable auto providerKey = format!"prov.%s.%s"(provider.type, provider.target);
        ProviderSet* bucket = providerKey in globalProviders;
        if (bucket is null)
        {
            globalProviders[providerKey] = ProviderSet();
            bucket = &globalProviders[providerKey];
        }
        bucket.providers[pkgID] = provider;
    }

    PackageCandidate[string] candidates;
    ProviderSet[string] globalProviders;
    string[string] filePaths;
}
