/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.info
 *
 * Show package details
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.info;

public import moss.core.cli;

import moss.client.cli : initialiseClient;
import moss.deps.registry;
import moss.client.ui;
import std.file : exists;
import std.stdio : writefln;
import std.experimental.logger;
import std.string : join, wrap, endsWith;
import moss.client.cobbleplugin;
import moss.client.remoteplugin;
import moss.client.statedb;
import std.algorithm : map;
import std.range : empty;

/**
 * Print a candidate
 */
static void printCandidate(scope ref RegistryItem item) @trusted
{
    ItemInfo info = item.info();
    auto rr = cast(RemotePlugin) item.plugin;

    static immutable longestColumn = 13;

    static void printRow(string columnID, string portion) @trusted
    {
        immutable length = longestColumn - columnID.length;
        writefln("%s %*s %s", Text(columnID).attr(Attribute.Bold), length, " ", portion);
    }

    printRow("Name", info.name);
    printRow("Version", info.versionID);

    if (!(rr is null))
    {
        printRow("Origin", Text(rr.remoteConfig.id).attr(Attribute.Underline).toString);
    }
    printRow("Homepage", info.homepage);
    printRow("Summary", Text(info.summary).attr(Attribute.Italic).toString);
    printRow("Description", Text(info.description).attr(Attribute.Italic).toString);
    printRow("Licenses", info.licenses.join(", "));

    auto dependencies = item.dependencies;
    if (!dependencies.empty)
    {
        auto deps = dependencies.map!((d) => d.toString).join(", ")
            .wrap(80 - longestColumn, "", "               ", 4);
        printRow("Dependencies", deps.endsWith("\n") ? deps[0 .. $ - 1] : deps);
    }

    auto providers = item.providers;
    if (!providers.empty)
    {
        auto provs = providers.map!((d) => d.toString).join(", ")
            .wrap(80 - longestColumn, "", "               ", 4);
        printRow("Providers", provs.endsWith("\n") ? provs[0 .. $ - 1] : provs);
    }
}

/**
 * Show package details
 */
@CommandName("info") @CommandHelp("Show package details", "TODO: Improve docs") struct InfoCommand
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
        if (argv.length < 1)
        {
            error("moss info: Expected more than one argument");
            return 1;
        }
        foreach (arg; argv)
        {
            /* Use cobbler plugin to parse .stone file(s) */
            if (arg.endsWith(".stone") && arg.exists)
            {
                cl.cobbler.loadPackage(arg).match!((Failure f) {
                    error(format!"Unable to parse %s: %s"(arg, f.message));
                }, (RegistryItem pkg) { printCandidate(pkg); writefln(""); });
                continue;
            }

            /* Otherwise look for it in index collections */
            auto pkgs = cl.registry.byName(arg);
            if (pkgs.empty)
            {
                errorf("Unable to find any package matching '%s'", arg);
                continue;
            }
            foreach (candidate; pkgs)
            {
                printCandidate(candidate);
                writefln("");
            }
        }
        return 0;
    }
}
