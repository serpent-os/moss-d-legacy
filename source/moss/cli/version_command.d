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

module moss.cli.version_command;

public import moss.core.cli;
import moss.core;

@CommandName("version")
@CommandHelp("Show the program version and exit")
public struct VersionCommand
{
    BaseCommand pt;
    alias pt this;

    @CommandEntry() int run(ref string[] argv)
    {
        import std.stdio;

        writefln("moss, version %s", moss.core.Version);
        writeln("\nCopyright © 2020 Serpent OS Developers");
        writeln("Available under the terms of the ZLib license");
        return ExitStatus.Success;
    }
}
