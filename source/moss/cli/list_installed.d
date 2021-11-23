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

module moss.cli.list_installed;

public import moss.core.cli;
import moss.core;
import moss.cli : MossCLI;
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
 * List all installed packages
 */
@CommandName("installed")
@CommandHelp("List all installed packages")
@CommandAlias("li")
public struct ListInstalledCommand
{
    /** Extend BaseCommand to provide a root group of commands */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the ListInstalledCommand
     */
    @CommandEntry() int run(ref string[] argv)
    {
        context.setRootDirectory((pt.findAncestor!MossCLI).rootDirectory);

        auto con = new MossController();
        scope (exit)
        {
            con.close();
        }

        /* Convert for display */
        auto installed = con.registryManager.listInstalled().map!((i) {
            auto info = i.info();
            return DisplayPackage("%s (%s)".format(info.name, info.versionID), info.summary);
        }).array();

        /* Sort for printing */
        installed.sort!((a, b) => a.lineLead < b.lineLead);

        /* Find largest lead line */
        int longestLen = cast(int) installed.maxElement!("a.lineLead.length").lineLead.length;
        longestLen += 2;
        foreach (i; installed)
        {
            writefln("  %*s - %s", longestLen, i.lineLead, i.lineTail);
        }
        return ExitStatus.Success;
    }
}
