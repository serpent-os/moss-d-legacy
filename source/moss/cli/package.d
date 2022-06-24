/* SPDX-License-Identifier: Zlib */

/**
 * moss.cli
 *
 * Module namespace imports.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module moss.cli;

public import moss.core.cli;
public import moss.cli.add;
public import moss.cli.add_repo;
public import moss.cli.extract_command;
public import moss.cli.inspect_command;
public import moss.cli.index_command;
public import moss.cli.info_command;
public import moss.cli.install_command;
public import moss.cli.list;
public import moss.cli.list_available;
public import moss.cli.list_installed;
public import moss.cli.version_command;
public import moss.cli.remove_command;
public import moss.cli.update_command;

/**
 * The MossCLI type holds some global configuration bits
 */
@RootCommand @CommandName("moss")
@CommandHelp("moss - the Serpent OS package management tool",
        "\nA system package manager tying together traditional requirements "
        ~ "with advanced features for improved control and reliability.")
@CommandUsage("[--args] [command]")
public struct MossCLI
{
    /** Extend BaseCommand to provide a root group of commands */
    BaseCommand pt;
    alias pt this;

    /** Option to set the root directory for filesystem operations */
    @Option("D", "destdir", "Root directory for all operations") string rootDirectory = "/";
}
