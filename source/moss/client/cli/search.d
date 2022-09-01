/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.search
 *
 * Search command
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.search;

public import moss.core.cli;

import moss.client.cli : initialiseClient;
import moss.deps.registry;

/**
 * Search command support
 */
@CommandName("search") @CommandAlias("sr") @CommandUsage("[term]") @CommandHelp(
        "Search for software", "TODO: Improve docs") struct SearchCommand
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
