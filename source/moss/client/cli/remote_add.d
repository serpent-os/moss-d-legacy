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
import std.format;
import std.stdio : writeln;
import std.sumtype;
import std.experimental.logger;
import moss.client.ui;
import std.stdint : uint64_t;

/**
 * Add a remote to the system
 */
@CommandName("add") @CommandAlias("ar") @CommandUsage("[name] [URI]") @CommandHelp(
        "Add a new remote .stone collection index to the system.",
        "\nSupports both file:/// and https:// transport protocols."
        ~ "\n\nExample URI: https://dev.serpentos.com/protosnek/x86_64/stone.index") struct RemoteAddCommand
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
            writeln("add: Requires [name] and [URI] parameters");
            return 1;
        }

        auto cl = initialiseClient(pt);
        scope (exit)
        {
            cl.close();
        }
        auto name = argv[0];
        auto url = argv[1];

        /* Only permit unique remotes */
        foreach (repo; cl.remotes.active)
        {
            if (name == repo.id)
            {
                error(format!"A remote %s already exists with this name. Choose a unique name."(
                        repo.id));
                return 1;
            }
            if (url == repo.uri)
            {
                error(format!"The uri %s already exists from the remote %s."(repo.uri, repo.id));
                return 1;
            }
            if (priority == repo.priority)
            {
                error(format!"%s already exists with the priority of %s. Choose a unique priority number."(repo.id,
                        repo.priority));
                return 1;
            }
        }

        return cl.remotes.add(name, url, priority).match!((Failure f) {
            errorf("%s", f.message);
            return 1;
        }, (_) { infof("Added remote %s", name); return 0; });
    }

    /**
     * Higher priority wins
     */
    @Option("p", "priority", "Priority to enable this remote with")
    uint64_t priority = 0;
}
