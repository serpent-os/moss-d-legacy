/*
 * This file is part of moss.
 *
 * Copyright © 2020-2021 Serpent OS Developers
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

module moss.cli;

public import moss.core.cli;
public import moss.cli.extract_command;
public import moss.cli.info_command;
public import moss.cli.install_command;
public import moss.cli.list;
public import moss.cli.list_installed;
public import moss.cli.version_command;
public import moss.cli.remove_command;

/**
 * The MossCLI type holds some global configuration bits
 */
@RootCommand @CommandName("moss")
@CommandHelp("moss - the Serpent OS package management tool",
        "\nA system package manager tying together traditional requirements "
        ~ "with advanced features for improved control and reliablity.")
@CommandUsage("[--args] [command]")
public struct MossCLI
{
    /** Extend BaseCommand to provide a root group of commands */
    BaseCommand pt;
    alias pt this;

    /** Option to set the root directory for filesystem operations */
    @Option("D", "destdir", "Root directory for all operations") string rootDirectory = "/";
}
