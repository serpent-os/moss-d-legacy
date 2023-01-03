/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.list_available
 *
 * List available packages
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.list_available;

public import moss.core.cli;

import moss.client.cli : initialiseClient;
import moss.client.cli.list : DisplayItem, printItem;
import moss.client.remoteplugin;
import moss.client.ui;
import moss.deps.registry;
import std.algorithm : each, filter, map, maxElement, sort, SwapStrategy, uniq;
import std.array : array;
import std.format;
import std.range : empty;

/**
 * List the available packages
 */
@CommandName("available") @CommandAlias("la") @CommandHelp(
        "List available packages", "TODO: Improve docs") struct ListAvailableCommand
{
    BaseCommand pt;
    alias pt this;

    @CommandEntry() int run(ref string[] argv) @safe
    {
        auto cl = initialiseClient(pt);
        scope (exit)
        {
            cl.close();
        }

        bool showCandidate(in RegistryItem item) @safe
        {
            if (collectionID.empty)
            {
                return true;
            }
            auto r = () @trusted { return cast(RemotePlugin) item.plugin; }();
            return (r !is null && r.remoteConfig.id == collectionID);
        }

        /* Grab all *unique* pkg names */
        auto uniqueNames = () @trusted {
            auto names = cl.registry.list(ItemFlags.Available).filter!showCandidate
                .map!((i) => cast(string) i.info.name)
                .array;
            names.sort;
            return names;
        }();

        /* Map a candidate's name to a display item */
        DisplayItem mappedName(string name) @safe
        {
            auto candidate = cl.registry.byName(name).front;
            auto info = candidate.info;
            return DisplayItem(info.name, info.summary,
                    format!"%s-%s"(info.versionID, info.releaseNumber));
        }

        DisplayItem[] di = () @trusted {
            return uniqueNames.uniq.map!mappedName.array;
        }();

        if (di.empty)
        {
            return 0;
        }
        di.sort!((a, b) => a.name < b.name);
        immutable largestName = di.maxElement!"a.name.length".name.length;
        immutable largestVersion = di.maxElement!"a.versionID.length".versionID.length;
        di.each!((d) => printItem(largestName + largestVersion, d));
        return 0;
    }

    /**
     * Collection ID to filter by
     */
    @Option("c", "collection", "Filter results by collection ID")
    string collectionID;
}
