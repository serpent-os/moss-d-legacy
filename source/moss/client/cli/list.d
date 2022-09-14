/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.list
 *
 * Listing support
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.list;

public import moss.core.cli;

import moss.client.ui;
import std.stdio : writeln;
import std.string : format;

/**
 * Grouping for listing commands
 */
@CommandName("list") @CommandUsage("[subcommand]]") @CommandHelp("List items", "TODO: Improve docs") struct ListCommand
{
    BaseCommand pt;
    alias pt this;
}

/**
 * Common helper struct to display items
 */
struct DisplayItem
{
    string name;
    string summary;
    string versionID;
}

/**
 * Print items with consistent formatting
 */
static void printItem(ulong longestName, ref DisplayItem item) @trusted
{
    immutable size = (longestName - (item.name.length + item.versionID.length)) + 2;
    writeln(format!" %s %*s %s - %s"(Text(item.name).attr(Attribute.Bold), size,
            " ", Text(item.versionID).fg(Color.Magenta), item.summary));
}
