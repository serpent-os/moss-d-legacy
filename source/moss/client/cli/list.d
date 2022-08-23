/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.list
 *
 * Listing support
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.list;

public import moss.core.cli;

/**
 * Grouping for listing commands
 */
@CommandName("list") @CommandUsage("[subcommand]]") @CommandHelp("List items", "TODO: Improve docs") struct ListCommand
{
    BaseCommand pt;
    alias pt this;
}
