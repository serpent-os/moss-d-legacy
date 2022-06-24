/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.cli.update_command
 *
 * Update local cache of moss index repository contents.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.cli.update_command;

public import moss.core.cli;
import moss.core;
import moss.cli : MossCLI;
import moss.context;
import moss.controller;

/**
 * The update command allows the user to request repository update to happen
 */
@CommandName("update")
@CommandHelp("Update system repository")
@CommandAlias("ur")
public struct UpdateCommand
{
    /** Extend BaseCommand with update utility */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the UpdateCommand
     */
    @CommandEntry() int run(ref string[] argv)
    {
        context.setRootDirectory((pt.findAncestor!MossCLI).rootDirectory);

        auto con = new MossController();
        scope (exit)
        {
            con.close();
        }

        con.updateRemotes();

        return ExitStatus.Success;
    }
}
