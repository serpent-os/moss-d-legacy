/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.cli.list
 *
 * List is a root command for listing moss items.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.cli.list;

public import moss.core.cli;

/**
 * The MossCLI type holds some global configuration bits
 */
@CommandName("list")
@CommandHelp("Emit listing of moss items")
@CommandUsage("[--args] [command]")
public struct ListCommand
{
    /** Extend BaseCommand to provide a root group of commands */
    BaseCommand pt;
    alias pt this;
}
