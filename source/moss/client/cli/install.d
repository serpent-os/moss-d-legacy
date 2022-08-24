/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.install
 *
 * Installation command
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.install;

public import moss.core.cli;

import moss.client.cli : initialiseClient;
import moss.deps.registry;
import std.stdio : writefln, writef;
import std.experimental.logger;
import std.range : empty;
import std.string : join, wrap, format;
import std.algorithm : map;
import moss.client.ui;

/**
 * Primary grouping for the moss cli
 */
@CommandName("install") @CommandAlias("it") @CommandUsage("[package name]") @CommandHelp(
        "Install software", "TODO: Improve docs") struct InstallCommand
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

        Transaction tx = cl.registry.transaction();
        RegistryItem[] selections;
        foreach (item; argv)
        {
            auto candidates = cl.registry.byName(item);
            if (candidates.empty)
            {
                errorf("Cannot find package %s", item);
                return 1;
            }
            auto chosen = candidates.front;
            () @trusted { tracef("Picking: %s", chosen); }();
            selections ~= chosen;
        }
        tx.installPackages(selections);
        auto result = tx.apply();
        auto problems = tx.problems();
        if (!problems.empty)
        {
            cl.ui.warn("Unable to install due to the following problems...");
            foreach (problem; problems)
            {
                cl.ui.inform!"[%s] %s"(problem.type, problem.item);
            }
        }
        cl.ui.inform("The following packages will be installed\n");
        ulong colWritten = 0;
        ulong elemWritten = 0;
        foreach (r; result)
        {
            if (r.installed)
            {
                continue;
            }
            auto writeLen = r.info.name.length + r.info.versionID.length + 1;
            auto toWrite = format!"%s %s"(Text(r.info.name)
                    .attr(Attribute.Bold), Text(r.info.versionID).fg(Color.Magenta));
            if (writeLen + colWritten > 64)
            {
                colWritten = 0;
                writef!"\n %s"(toWrite);
            }
            else
            {
                if (elemWritten == 0)
                {
                    writef!" %s"(toWrite);
                    colWritten += writeLen;
                }
                else
                {
                    writef!", %s"(toWrite);
                    colWritten += writeLen + 2;
                }
            }
            ++elemWritten;
        }
        writef("\n");

        return 0;
    }
}
