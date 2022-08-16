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
        return 0;
    }
}
