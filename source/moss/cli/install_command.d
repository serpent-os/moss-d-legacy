/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.cli.install_command
 *
 * Install local or remote .stone packages.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.cli.install_command;

public import moss.core.cli;
import moss.core;
import moss.cli : MossCLI;
import moss.context;
import moss.controller;

/**
 * The InstallCommand provides a CLI system to install a package, whether from
 * a local file or a repository.
 */
@CommandName("install")
@CommandHelp("Install a package to the system (named or .stone file)")
@CommandAlias("it")
@CommandUsage("[.stone file] [package name]")
public struct InstallCommand
{
    /** Extend BaseCommand with install utility */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the InstallCommand
     */
    @CommandEntry() int run(ref string[] argv)
    {
        context.setRootDirectory((pt.findAncestor!MossCLI).rootDirectory);

        auto con = new MossController();
        scope (exit)
        {
            con.close();
        }
        con.ignoreDependencies = ignoreDependencies;

        /* Install the packages */
        con.installPackages(argv);

        return ExitStatus.Success;
    }

    /** For the insane and the bootstrap */
    @Option("ignore-dependency", null, "Ignore missing dependencies. Use at own peril") bool ignoreDependencies;
}
