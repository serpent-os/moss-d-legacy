/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.remote_update
 *
 * Refresh remotes
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.remote_update;

public import moss.core.cli;

import moss.client.cli : initialiseClient;
import moss.core.errors;
import std.stdio : writeln;
import std.sumtype;
import std.experimental.logger;
import moss.client.ui;

/**
 * Add a remote to the system
 */
@CommandName("update") @CommandAlias("ur") @CommandHelp("Refresh remotes", "TODO: Improve docs") struct RemoteUpdateCommand
{
    BaseCommand pt;
    alias pt this;

    /**
     * Dispatch the add command
     */
    @CommandEntry() int run(ref string[] argv) @safe
    {
        auto cl = initialiseClient(pt);
        scope (exit)
        {
            cl.close();
        }

        return cl.remotes.refresh().match!((Failure f) {
            errorf("%s", f.message);
            return 1;
        }, (_) { infof("Refreshed remotes"); return 0; });
    }
}
