/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.cli.list_packages
 *
 * List all/available/installed .stone packages.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.cli.list_packages;

import moss.core : ExitStatus;
import moss.context;
import moss.controller;
import moss.deps.registry.item;

import std.stdio : writeln, writefln;
import std.algorithm : map, sort, maxElement;
import std.array : array;
import std.string : format;

struct DisplayPackage
{
    string lineLead;
    string lineTail;
}

/**
 * Specific listing mode
 */
package enum ListMode
{
    All,
    Installed,
    Available,
}

/**
 * Helper for listing packages for the CLI subcommands
 */
public ExitStatus listPackages(ListMode mode)
{
    auto con = new MossController();
    scope (exit)
    {
        con.close();
    }

    /**
     * Filter the selections
     */
    ItemFlags flags = ItemFlags.None;
    final switch (mode)
    {
    case ListMode.All:
        flags = ItemFlags.None;
        break;
    case ListMode.Installed:
        flags = ItemFlags.Installed;
        break;
    case ListMode.Available:
        flags = ItemFlags.Available;
        break;
    }

    auto results = con.registryManager.list(flags);
    if (results.empty)
    {
        writeln("Could not find any packages");
        return ExitStatus.Failure;
    }
    auto pkgs = results.map!((i) {
        auto info = i.info();
        return DisplayPackage("%s (%s)".format(info.name, info.versionID), info.summary);
    }).array();

    /* Sort for printing */
    if (pkgs.length > 0)
    {
        pkgs.sort!((a, b) => a.lineLead < b.lineLead);
    }

    /* Find largest lead line */
    int longestLen = cast(int) pkgs.maxElement!("a.lineLead.length").lineLead.length;
    longestLen += 2;
    foreach (i; pkgs)
    {
        writefln!"  %*s - %s"(longestLen, i.lineLead, i.lineTail);
    }
    return ExitStatus.Success;
}
