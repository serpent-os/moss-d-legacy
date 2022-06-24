/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.cli.list_available
 *
 * List all available .stone packages in a collection.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.cli.list_available;

public import moss.core.cli;
import moss.core;
import moss.cli : MossCLI;
import moss.context;

import moss.cli.list_packages;

/**
 * List all installed packages
 */
@CommandName("available")
@CommandHelp("List all available packages")
@CommandAlias("la")
public struct ListAvailableCommand
{
    /** Extend BaseCommand to provide a root group of commands */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the ListAvailableCommand
     */
    @CommandEntry() int run(ref string[] argv)
    {
        context.setRootDirectory((pt.findAncestor!MossCLI).rootDirectory);

        return listPackages(ListMode.Available);
    }
}
