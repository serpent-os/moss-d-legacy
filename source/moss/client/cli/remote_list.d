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
import std.stdio : writeln;
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

        /* Get the max length to calculate padding */
        ulong idMaxLen = 0;
        ulong uriMaxLen = 0;
        foreach (rm; cl.remotes.active)
        {
            auto idLen = rm.id.length;
            if (idLen > idMaxLen)
            {
                idMaxLen = idLen;
            }
            auto uriLen = rm.uri.length;
            if (uriLen > uriMaxLen)
            {
                uriMaxLen = uriLen;
            }
        }

        /* print it out */
        foreach (rm; cl.remotes.active)
        {
            /* Calculate padding between elements for consistent output */
            auto idPadding = (idMaxLen - rm.id.length) + 1;
            auto uriPadding = (uriMaxLen - rm.uri.length) + 1;

            /* id, idPadding, active, uri, uriPadding, priority, priorityNum, comment, descString */
            writeln(format!"%s %*s %s %s %*s %s %s %s %s"(Text(rm.id)
                    .fg(Color.Magenta).attr(Attribute.Bold), idPadding, " ",
                    Text("[active]").fg(Color.Green), Text(rm.uri)
                    .fg(Color.White), uriPadding, " ", Text("Priority:").fg(Color.Blue),
                    rm.priority, Text("Comment:").fg(Color.Yellow),
                    Text(rm.description).attr(Attribute.Italic)));
        }
        return 0;
    }
}
