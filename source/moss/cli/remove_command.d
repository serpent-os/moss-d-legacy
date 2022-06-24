/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.cli.remove_command
 *
 * Remove .stone package(s) from the system.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.cli.remove_command;

public import moss.core.cli;
import moss.core;
import moss.cli : MossCLI;
import moss.context;
import moss.controller;

/**
 * The removeCommand provides a CLI system to remove a package, whether from
 * a local file or a repository.
 */
@CommandName("remove")
@CommandHelp("Remove the named package(s) from the system")
@CommandAlias("rm")
@CommandUsage("[package name]")
public struct RemoveCommand
{
    /** Extend BaseCommand with remove utility */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the RemoveCommand
     */
    @CommandEntry() int run(ref string[] argv)
    {
        context.setRootDirectory((pt.findAncestor!MossCLI).rootDirectory);

        auto con = new MossController();
        scope (exit)
        {
            con.close();
        }

        /* Install the packages */
        con.removePackages(argv);

        return ExitStatus.Success;
    }
}
