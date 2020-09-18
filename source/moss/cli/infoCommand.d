/*
 * This file is part of moss.
 *
 * Copyright © 2020 Serpent OS Developers
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

/**
 * Build command implementation
 */
module moss.cli.infoCommand;
import moss.cli;
import moss.format.binary.reader;

import std.stdio : writeln, stderr;

static ExitStatus infoExecute(ref Processor p)
{
    if (p.argv.length != 1)
    {
        stderr.writeln("Requires an argument");
        return ExitStatus.Failure;
    }

    auto reader = Reader(File(p.argv[0], "rb"));

    foreach (entry; reader)
    {
        switch (entry.type)
        {
        case EntryType.Header:
            writeln(entry.header);
            break;
        case EntryType.Record:
            writeln(entry.record);
            break;
        default:
            break;
        }
    }

    return ExitStatus.Failure;
}

const Command infoCommand = {
    primary: "info", secondary: null, blurb: "Show package details", usage: "info [package]",
    exec: &infoExecute, helpText: `
Display information on a package
`
};
