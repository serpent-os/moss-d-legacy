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

        /* Install the packages */
        con.installPackages(argv);

        return ExitStatus.Success;
    }
}
