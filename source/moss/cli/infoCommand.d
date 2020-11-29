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

module moss.cli.infoCommand;

public import moss.core.cli;
import moss.core;
import moss.format.binary.reader;
import std.stdio;

@CommandName("info")
@CommandHelp("Display information on a package",
        "With a locally available .stone file, this command will attempt to read,
validate and extract information on the given package.
If the file is not a valid .stone file for moss, an error will be reported.")
@CommandUsage("[.stone file]")
public final struct InfoCommand
{
    BaseCommand pt;
    alias pt this;

    @CommandEntry() int run(ref string[] argv)
    {
        if (argv.length != 1)
        {
            stderr.writeln("Requires an argument");
            return ExitStatus.Failure;
        }

        auto reader = Reader(File(argv[0], "rb"));

        foreach (payload; reader)
        {
            final switch (payload.type)
            {
            case PayloadType.Attributes:
                writeln(" - Attributes payload");
                break;
            case PayloadType.Content:
                writeln(" - Content payload");
                break;
            case PayloadType.Index:
                writeln(" - Index payload");
                break;
            case PayloadType.Layout:
                writeln(" - Layout payload");
                break;
            case PayloadType.Meta:
                writeln(" - Meta payload");
                break;
            case PayloadType.Unknown:
                writeln(" - Unknown payload");
                break;
            }
            writeln(payload);
        }

        return ExitStatus.Failure;
    }
}
