/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.remote_remove
 *
 * Remove remotes from the system
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.remote_remove;

public import moss.core.cli;

import moss.client.cli : initialiseClient;
import moss.client.ui;
import moss.client.cli : MossCLI;
import moss.client.cli.list : DisplayItem, printItem;
import moss.core.errors;
import moss.client.remoteplugin;
import std.algorithm : each, filter, map, maxElement, sort, SwapStrategy;
import std.array : array, empty;
import std.experimental.logger;
import std.string : format;
import std.stdio : writeln;

/**
 * Remove a remote from the system
 */
@CommandName("remove") @CommandAlias("rr") @CommandUsage("[name]") @CommandHelp(
        "Remove an existing remote collection index from the system.") struct RemoteRemoveCommand
{
    BaseCommand pt;
    alias pt this;

    /**
     * Dispatch the remove command
     */
    @CommandEntry() int run(ref string[] argv) @safe
    {
        if (argv.length != 1)
        {
            writeln("remove: Requires [name] as a parameter");
            return 1;
        }

        auto base = () @trusted { return pt.findAncestor!MossCLI; }();
        auto cl = initialiseClient(pt);
        scope (exit)
        {
            cl.close();
        }
        auto name = argv[0];

        auto match = cl.remotes.active.filter!((r) => r.id == name);
        if (match.empty)
        {
            error(format!"remote %s not found. Use 'remote list' to view remotes."(name));
            return 1;
        }

        if (cl.remotes.active.length == 1)
        {
            error("Refusing to remove only existing remote.");
            return 1;
        }

        /* Search for any would be orphaned packages from removing the remote */
        DisplayItem[] di = () @trusted {
            return cl.registry.list(ItemFlags.Installed).filter!((i) {
                auto altCandidates = cl.registry.byID(i.pkgID).filter!((rp) {
                    if (rp.installed)
                    {
                        return false;
                    }
                    auto r = cast(RemotePlugin) rp.plugin;
                    if (r !is null && r.remoteConfig.id == name)
                    {
                        return true;
                    }
                    return false;
                });
                return !altCandidates.empty;
            })
                .map!((i) {
                    auto info = i.info();
                    return DisplayItem(info.name, info.summary,
                        format!"%s-%s"(info.versionID, info.releaseNumber));
                })
                .array();
        }();

        /* We have orphaned packages, let the user know */
        if (!di.empty)
        {
            di.sort!((a, b) => a.name < b.name);
            immutable largestName = di.maxElement!"a.name.length".name.length;
            immutable largestVersion = di.maxElement!"a.versionID.length".versionID.length;

            cl.ui.warn("The following packages would be orphaned by removing this remote\n");
            di.each!((d) => printItem(largestName + largestVersion, d));

            /* FIXME: Allow user to automatically remove the orphaned packages */
            if (!base.yesAll)
            {
                cl.ui.inform("");
                if (!cl.ui.ask("Do you want to continue?"))
                {
                    cl.ui.warn("Exiting at user's request");
                    return 1;
                }
            }
        }

        return cl.remotes.remove(name).match!((Failure f) {
            errorf("%s", f.message);
            return 1;
        }, (_) { info(format!"Removed remote %s"(name)); return 0; });
    }
}
