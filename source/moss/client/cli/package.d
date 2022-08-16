/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client
 *
 * Client API for moss
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli;

public import moss.core.cli;

/**
 * Primary grouping for the moss cli
 */
@CommandName("moss") @CommandUsage("[command]") @CommandHelp("moss system software management",
        "The advanced system management tool from Serpent OS") @RootCommand struct MossCLI
{
    BaseCommand pt;
    alias pt this;

    /**
     * Create new CLI handler
     *
     * Params:
     *      args = Runtime arguments
     * Returns: Newly initialised handler
     */
    static auto construct(ref string[] args) @trusted
    {
        return cliProcessor!MossCLI(args);
    }
}
