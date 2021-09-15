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

module moss.cli.remove_command;

public import moss.core.cli;
import moss.core;
import moss.cli : MossCLI;
import moss.context;
import moss.jobs;
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

        /* Hack, exit when needed */
        mainLoop.idleAdd(() => {
            if (context.jobs.hasJobs)
            {
                return CallbackControl.Continue;
            }
            mainLoop.quit();
            return CallbackControl.Stop;
        }());
        mainLoop.run();

        return ExitStatus.Success;
    }
}
