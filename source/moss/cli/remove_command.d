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
import moss.client;

/**
 * The removeCommand provides a CLI system to remove a package, whether from
 * a local file or a repository.
 */
@CommandName("remove")
@CommandHelp("remove a local package")
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
        /* Set up context and our client */
        context.setRootDirectory((pt.findAncestor!MossCLI).rootDirectory);
        auto client = new DirectMossClient();
        scope (exit)
        {
            client.close();
        }

        try
        {
            client.removePackages(argv);
        }
        catch (Exception ex)
        {
            return ExitStatus.Failure;
        }

        return ExitStatus.Success;
    }
}
