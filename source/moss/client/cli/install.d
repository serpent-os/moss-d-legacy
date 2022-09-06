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
import std.algorithm : map, filter;
import moss.client.ui;
import moss.client.statedb;

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
            auto search = fromString!Provider(item);
            auto candidates = cl.registry.byProvider(search.type, search.target);
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
        auto newPkgs = result.filter!((p) => !p.installed);
        cl.ui.emitAsColumns(newPkgs);
        cl.ui.inform("");
        if (!cl.ui.ask("Do you want to continue?"))
        {
            cl.ui.warn("Exiting at user's request");
            return 1;
        }
        /* Do the deal. */
        cl.applyTransaction(tx);
        return 0;
    }
}
