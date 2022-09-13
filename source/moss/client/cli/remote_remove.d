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
import moss.core.errors;
import std.algorithm : filter;
import std.array;
import std.format;
import std.stdio : writeln;
import std.sumtype;
import std.experimental.logger;
import moss.client.ui;
import std.stdint : uint64_t;

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

        /* FIXME: Show all .stones that would be orphaned due to coming from this remote */

        return cl.remotes.remove(name).match!((Failure f) {
            errorf("%s", f.message);
            return 1;
        }, (_) { infof("Removed remote %s", name); return 0; });
    }
}
