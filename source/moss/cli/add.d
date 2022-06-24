/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.cli.add
 *
 * Subcommand group for 'moss add'.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.cli.add;

public import moss.core.cli;

/**
 * Provide subcommand grouping
 */
@CommandName("add")
@CommandHelp("Add repositories, etc.")
@CommandUsage("[--args] [command]")
public struct AddCommand
{
    /** Extend BaseCommand to provide a root group of commands */
    BaseCommand pt;
    alias pt this;
}
