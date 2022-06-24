/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.cli.list_installed
 *
 * moss.cli.list_installed
 *
 * List all installed .stone packages.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.cli.list_installed;

public import moss.core.cli;
import moss.core;
import moss.cli : MossCLI;
import moss.context;

import moss.cli.list_packages;

/**
 * List all installed packages
 */
@CommandName("installed")
@CommandHelp("List all installed packages")
@CommandAlias("li")
public struct ListInstalledCommand
{
    /** Extend BaseCommand to provide a root group of commands */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the ListInstalledCommand
     */
    @CommandEntry() int run(ref string[] argv)
    {
        context.setRootDirectory((pt.findAncestor!MossCLI).rootDirectory);

        return listPackages(ListMode.Installed);
    }
}
