/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.remote_add
 *
 * Add remotes to the system
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.remote_add;

public import moss.core.cli;

import moss.client.cli : initialiseClient;
import moss.core.errors;
import std.stdio : writeln;
import std.sumtype;
import std.experimental.logger;

/**
 * Add a remote to the system
 */
@CommandName("add") @CommandAlias("ar") @CommandUsage("[name] [url]") @CommandHelp(
        "Add a new remote to the system", "TODO: Improve docs") struct RemoteAddCommand
{
    BaseCommand pt;
    alias pt this;

    /**
     * Dispatch the add command
     */
    @CommandEntry() int run(ref string[] argv) @safe
    {
        if (argv.length != 2)
        {
            writeln("add: Requires [name] and [url] parameters");
            return 1;
        }

        auto cl = initialiseClient(pt);
        scope (exit)
        {
            cl.close();
        }
        auto name = argv[0];
        auto url = argv[1];

        return cl.remotes.add(name, url).match!((Failure f) {
            errorf("%s", f.message);
            return 1;
        }, (_) { infof("Added remote %s", name); return 0; });
    }
}
