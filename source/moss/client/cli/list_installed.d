/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.list_installed
 *
 * List installed packages
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.list_installed;

public import moss.core.cli;

import moss.client.cli : initialiseClient;
import moss.deps.registry;
import moss.client.ui;
import std.stdio : writefln;
import std.algorithm : map;
import std.array : array;
import std.algorithm : each, sort, SwapStrategy, maxElement;
import std.range : empty;
import moss.client.cli.list_available : DisplayItem;

static void printItem(ulong longestName, ref DisplayItem item) @trusted
{
    immutable size = (longestName - (item.name.length + item.versionID.length)) + 2;
    writefln(" %s %*s %s - %s", Text(item.name).attr(Attribute.Bold), size,
            " ", Text(item.versionID).fg(Color.Magenta), item.summary);
}

/**
 * List the installed packages
 */
@CommandName("installed") @CommandAlias("li") @CommandHelp(
        "List installed packages", "TODO: Improve docs") struct ListInstalledCommand
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
        DisplayItem[] di = () @trusted {
            return cl.registry.list(ItemFlags.Installed).map!((i) {
                auto info = i.info();
                return DisplayItem(info.name, info.summary,
                    format!"%s-%s"(info.versionID, info.releaseNumber));
            }).array();
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
}
