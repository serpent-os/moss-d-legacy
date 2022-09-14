/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.remote
 *
 * Remote management
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.remote;

public import moss.core.cli;

import moss.client.cli : initialiseClient;

/**
 * Primary grouping for the moss cli
 */
@CommandName("remote") @CommandUsage("[subcommand]]") @CommandHelp(
        "Manage system remotes", "TODO: Improve docs") struct RemoteCommand
{
    BaseCommand pt;
    alias pt this;
}

immutable auto SupportedProtocols = ["https://", "http://", "file://", "ftp://"];
