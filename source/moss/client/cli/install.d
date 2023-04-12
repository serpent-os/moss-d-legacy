/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.install
 *
 * Installation command
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.install;

public import moss.core.cli;

import moss.client.cli : initialiseClient;
import moss.deps.registry;
import std.stdio : writefln, writef, writeln;
import std.experimental.logger;
import std.range : empty;
import std.string : join, wrap, format, endsWith;
import std.algorithm : map, filter;
import moss.client.ui;
import moss.client.statedb;
import moss.client.cli : MossCLI;
import std.file : exists;

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
        auto base = () @trusted { return pt.findAncestor!MossCLI; }();
        auto cl = initialiseClient(pt);
        scope (exit)
        {
            cl.close();
        }

        RegistryItem[] selections;
        foreach (item; argv)
        {
            /* Is this a local .stone file ? */
            if (item.endsWith(".stone") && item.exists)
            {
                bool shouldExit;
                cl.cobbler.loadPackage(item).match!((Failure f) {
                    error(format!"Unable to load %s: %s"(item, f.message));
                    shouldExit = true;
                }, (RegistryItem pkg) {
                    () @trusted { trace(format!"Sideloading: %s"(pkg)); }();
                    selections ~= pkg;
                });
                if (shouldExit)
                {
                    return 1;
                }
                continue;
            }
            auto search = fromString!Provider(item);
            auto candidates = cl.registry.byProvider(search.type, search.target);
            if (candidates.empty)
            {
                error(format!"Cannot find package %s"(item));
                return 1;
            }
            auto chosen = candidates.front;
            () @trusted { trace(format!"Picking: %s"(chosen)); }();
            selections ~= chosen;
        }
        Transaction tx = cl.registry.transaction();
        tx.installPackages(selections);
        auto result = tx.apply();
        auto problems = tx.problems();
        if (!problems.empty)
        {
            cl.ui.warn("Unable to install due to the following problems...");
            writeln();
            foreach (problem; problems)
            {
                cl.ui.inform!" - [%s] %s"(Text(format!"%s"(problem.type))
                        .attr(Attribute.Bold), Text(problem.dependency.toString).fg(Color.Red));
            }
            return 1;
        }
        cl.ui.inform!"The following %d package(s) will be installed\n"(result.length);
        auto newPkgs = result.filter!((p) => !p.installed);
        cl.ui.emitAsColumns(newPkgs);
        cl.ui.inform("");
        if (!base.yesAll)
        {
            if (!cl.ui.ask("Do you want to continue?"))
            {
                cl.ui.warn("Exiting at user's request");
                return 1;
            }
        }
        /* Do the deal. */
        cl.applyTransaction(tx);
        return 0;
    }
}
