/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli
 *
 * Base command for our CLI
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli;

public import moss.core.cli;

import moss.client.cli.index;
import moss.client.cli.info;
import moss.client.cli.install;
import moss.client.cli.list;
import moss.client.cli.list_available;
import moss.client.cli.list_installed;
import moss.client.cli.remote;
import moss.client.cli.remote_add;
import moss.client.cli.remote_list;
import moss.client.cli.remote_update;
import moss.client.cli.remote_remove;
import moss.client.cli.remove;
import moss.client.cli.search;
import moss.client;
import std.experimental.logger;

package auto initialiseClient(scope ref BaseCommand pt) @trusted
{
    auto rootCLI = pt.findAncestor!MossCLI;

    /**
     * Enable all trace statements
     */
    if (rootCLI.debugging)
    {
        globalLogLevel = LogLevel.trace;
    }

    /* Enable the client now */
    auto cl = new MossClient(rootCLI.rootDirectory);

    return cl;
}

/**
 * Primary grouping for the moss cli
 */
@CommandName("moss") @CommandUsage("[command]") @CommandHelp("moss system software management",
        "The advanced system management tool from Serpent OS") @RootCommand struct MossCLI
{
    BaseCommand pt;
    alias pt this;

    /**
     * Create new CLI handler
     *
     * Params:
     *      args = Runtime arguments
     * Returns: Newly initialised handler
     */
    static auto construct(ref string[] args) @trusted
    {
        auto p = cliProcessor!MossCLI(args);
        p.addCommand!IndexCommand;
        p.addCommand!InstallCommand;
        auto list = p.addCommand!ListCommand;
        list.addCommand!ListAvailableCommand;
        list.addCommand!ListInstalledCommand;
        auto remotes = p.addCommand!RemoteCommand;
        remotes.addCommand!RemoteAddCommand;
        remotes.addCommand!RemoteRemoveCommand;
        remotes.addCommand!RemoteListCommand;
        remotes.addCommand!RemoteUpdateCommand;
        p.addCommand!InfoCommand;
        p.addCommand!RemoveCommand;
        p.addCommand!SearchCommand;
        return p;
    }

    /**
     * Enable debugging
     */
    @Option("d", "debug", "Toggle debugging")
    bool debugging = false;

    /**
     * Root directory for all operations
     */
    @Option("D", "directory", "Root directory")
    string rootDirectory = "/";

    /**
     * Assume yes for all questions
     */
    @Option("y", "yes-all", "Assume yes for all questions")
    bool yesAll;
}
