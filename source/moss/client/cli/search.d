/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.search
 *
 * Search command
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.search;

public import moss.core.cli;

import moss.client.cli : initialiseClient;
import moss.deps.registry;
import std.experimental.logger;
import std.regex;
import std.algorithm : map, filter, sort, maxElement;
import std.stdio : writefln;
import moss.client.ui;
import std.array : array;

import moss.client.cli.list : DisplayItem;

public enum SearchMode
{
    all,
    description,
    summary,
    name,
}

/**
 * Search command support
 */
@CommandName("search") @CommandAlias("sr") @CommandUsage("[term]") @CommandHelp(
        "Search for software", "TODO: Improve docs") struct SearchCommand
{
    BaseCommand pt;
    alias pt this;

    /**
     * Handle installation
     */
    @CommandEntry() int run(ref string[] argv) @safe
    {
        auto cl = initialiseClient(pt);
        scope (exit)
        {
            cl.close();
        }
        auto matchers = argv.map!((a) => regex(a, ['g', 'i', 's']));
        if (matchers.empty)
        {
            error("search: Expected at least one argument");
            return 1;
        }
        /* For now we only support available, not installed */
        auto inputItems = cl.registry.list(ItemFlags.Available);
        auto matching = inputItems.filter!((item) {
            final switch (mode)
            {
            case SearchMode.description:
                auto matchingFilters = matchers.filter!((m) => !(matchFirst(item.info.description,
                    m).empty));
                return !matchingFilters.empty;
            case SearchMode.summary:
                auto matchingFilters = matchers.filter!((m) => !(matchFirst(item.info.summary,
                    m).empty));
                return !matchingFilters.empty;
            case SearchMode.name:
                auto matchingFilters = matchers.filter!((m) => !(matchFirst(item.info.name,
                    m).empty));
                return !matchingFilters.empty;
            case SearchMode.all:
                auto matchingFilters = matchers.filter!((m) => !(matchFirst(item.info.name,
                    m).empty || !(matchFirst(item.info.summary, m).empty))
                    || !(matchFirst(item.info.description, m).empty));
                return !matchingFilters.empty;
            }
        });
        if (matching.empty)
        {
            error("Failed to find any items");
            return 1;
        }

        /* Replace all matches with red underline text */
        auto highlightResult(string input)
        {
            foreach (m; matchers)
            {
                input = replaceAll(input, m, Text("$&").fg(Color.Red)
                        .attr(Attribute.Underline).toString);
            }
            return input;
        }

        auto di = matching.map!((i) {
            ItemInfo info = i.info;
            return DisplayItem(info.name, info.summary,
                format!"%s-%s"(info.versionID, info.releaseNumber));
        }).array();
        di.sort!"a.name < b.name";

        immutable largestName = di.maxElement!"a.name.length".name.length;
        immutable largestVersion = di.maxElement!"a.versionID.length".versionID.length;
        immutable width = largestName + largestVersion;

        /* Render the matches */
        foreach (item; di)
        {
            auto name = mode == SearchMode.all || mode == SearchMode.name
                ? highlightResult(item.name) : item.name;
            auto summary = mode == SearchMode.all || mode == SearchMode.summary
                ? highlightResult(item.summary) : item.summary;
            immutable size = (width - (item.name.length + item.versionID.length)) + 2;
            writefln(" %s %*s %s - %s", Text(name).attr(Attribute.Bold), size,
                    " ", Text(item.versionID).fg(Color.Magenta), summary);
        }
        return 0;
    }

    @Option("m", "mode", "Search mode (all, name, description, summary)") SearchMode mode = SearchMode
        .name;
}
