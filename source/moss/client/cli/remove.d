/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.remove
 *
 * Removal command
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.remove;

public import moss.core.cli;

import moss.client.cli : initialiseClient;
import moss.deps.registry;
import std.experimental.logger;
import std.algorithm : filter;
import std.range : empty;
import moss.client.ui;
import moss.client.impl : MossClient;
import std.array : array;
import std.stdio : writeln;

/**
 * Primary grouping for the moss cli
 */
@CommandName("remove") @CommandAlias("rm") @CommandUsage("[package name]") @CommandHelp(
        "Remove software", "TODO: Improve docs") struct RemoveCommand
{
    BaseCommand pt;
    alias pt this;

    /**
     * Handle installation
     */
    @CommandEntry() int run(ref string[] argv) @safe
    {
        MossClient cl = initialiseClient(pt);
        scope (exit)
        {
            cl.close();
        }

        RegistryItem[] removals;
        foreach (arg; argv)
        {
            auto candidates = cl.registry.byName(arg);
            if (candidates.empty)
            {
                errorf("No candidates matching '%s'", arg);
                return 1;
            }
            auto installedPkg = candidates.filter!((p) => p.installed);
            if (installedPkg.empty)
            {
                warningf("Cannot remove %s as it is not installed", Text(arg)
                        .fg(Color.Red).attr(Attribute.Bold));
                continue;
            }
            removals ~= installedPkg.front;
        }
        if (removals.empty)
        {
            error("Nothing to remove");
            return 1;
        }

        Transaction tx = cl.registry.transaction();
        tx.removePackages(removals);
        auto result = tx.apply();
        if (!tx.problems.empty)
        {
            errorf("Problems with transaction");
            return 1;
        }
        cl.ui.warn!"The following packages will be %s"(Text("removed")
                .fg(Color.Red).attr(Attribute.Underline));
        writeln();
        () @trusted { cl.ui.emitAsColumns(cast(RegistryItem[]) tx.removedItems); }();
        writeln();
        if (!cl.ui.ask("Do you REALLY want to proceed?"))
        {
            cl.ui.inform("No changes have been made to your system");
            return 1;
        }

        cl.applyTransaction(tx);
        return 0;
    }
}
