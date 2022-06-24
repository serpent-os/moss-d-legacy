/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.controller.plugins.cobble
 *
 * The CobblePlugin emulates a proper moss index repository of .stone
 * packages using a local on-disk directory with .stone packages.
 *
 * This allows local installation ("side-loading") without needing a
 * full-fat remote moss index repository served via https etc.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
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
import std.exception : enforce;

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
    override NullableRegistryItem queryID(in string pkgID)
    {
        auto match = pkgID in candidates;
        if (match !is null)
        {
            return NullableRegistryItem(RegistryItem(match.id, this, ItemFlags.Available));
        }

        return NullableRegistryItem();
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
    RegistryItem load(in string path)
    {
        auto fp = File(path, "rb");
        auto reader = new Reader(fp);
        string summary;
        string description;
        string homepage;
        string[] licenses;

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
            case RecordTag.Homepage:
                homepage = record.get!string;
                break;
            case RecordTag.Summary:
                summary = record.get!string;
                break;
            case RecordTag.Description:
                description = record.get!string;
                break;
            case RecordTag.License:
                licenses ~= record.get!string;
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
        infos[id] = new ItemInfo(candidate.name, summary, description, candidate.release,
                candidate.versionID, homepage, cast(immutable(string)[]) licenses);

        return queryID(id);
    }

    /**
     * Return the package IDs loaded (successfully) into this CobblePlugin to allow
     * use with states.
     */
    auto items()
    {
        return candidates.keys.map!((c) => RegistryItem(c, this, ItemFlags.Available));
    }

    auto itemPath(in string pkgID) const
    {
        return filePaths[pkgID];
    }

    /**
     * Return usable information for the package
     */
    override ItemInfo info(in string pkgID) const
    {
        return *infos[pkgID];
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

    /**
     * Do nothing, no resources here
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
    ItemInfo*[string] infos;
}
