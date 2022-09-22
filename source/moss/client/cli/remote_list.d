/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.remote_list
 *
 * List remotes on the system
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.remote_list;

public import moss.core.cli;

import moss.client.cli : initialiseClient;
import moss.client.ui;
import std.stdio : writeln, writefln;
import std.string : format;

/**
 * List remotes on the system
 */
@CommandName("list") @CommandAlias("lr") @CommandHelp("List system remotes", "TODO: Improve docs") struct RemoteListCommand
{
    BaseCommand pt;
    alias pt this;

    /**
     * Dispatch the list command
     */
    @CommandEntry() int run(ref string[] argv) @safe
    {
        auto cl = initialiseClient(pt);
        scope (exit)
        {
            cl.close();
        }

        foreach (rm; cl.remotes.active)
        {
            writeln(format!"%s %s %s %s %s %s %s"(Text(rm.id)
                    .fg(Color.Magenta).attr(Attribute.Bold), Text("[active]")
                    .fg(Color.Green), Text(rm.uri).fg(Color.White),
                    Text("Priority:").fg(Color.Blue), rm.priority, Text("Description:")
                    .fg(Color.Yellow), Text(rm.description).attr(Attribute.Italic)));
        }
        return 0;
    }
}
