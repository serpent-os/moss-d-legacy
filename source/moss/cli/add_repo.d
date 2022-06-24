/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.cli.add_repo
 *
 * Add a moss index repository to the system.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.cli.add_repo;

public import moss.core.cli;
import moss.core;
import moss.cli : MossCLI;
import moss.context;

import moss.cli.list_packages;

/**
 * Add repository to the system
 */
@CommandName("repo")
@CommandHelp("Add a repository to the system")
@CommandAlias("ar")
public struct AddRepoCommand
{
    /** Extend BaseCommand to provide a root group of commands */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the AddRepoCommand
     */
    @CommandEntry() int run(ref string[] argv)
    {
        context.setRootDirectory((pt.findAncestor!MossCLI).rootDirectory);

        return ExitStatus.Failure;
    }
}
