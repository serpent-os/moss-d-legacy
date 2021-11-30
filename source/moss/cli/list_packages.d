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
        writefln("  %*s - %s", longestLen, i.lineLead, i.lineTail);
    }
    return ExitStatus.Success;
}
