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
 * HelpCommand implementation
 */
module moss.cli.helpCommand;
import moss.cli;

static ExitStatus helpExecute(ref Processor p)
{
    import std.stdio;

    switch (p.argv.length)
    {
    case 0:
        p.printUsage();
        writeln();
        p.printGlobalHelp();
        return ExitStatus.Success;
    case 1:
        auto cmd = p.findHandler(p.argv[0]);
        if (cmd is null)
        {
            stderr.writefln("Unknown command: %s", cmd);
            return ExitStatus.Failure;
        }
        if (cmd.secondary !is null)
        {
            writefln("%s (%s) - %s\n", cmd.primary, cmd.secondary, cmd.blurb);
        }
        else
        {
            writefln("%s - %s\n", cmd.primary, cmd.blurb);
        }
        writefln("Usage: %s %s\n", p.name, cmd.usage !is null ? cmd.usage : p.argv[0]);
        writeln(cmd.helpText);
        return ExitStatus.Success;
    default:
        p.printUsage();
        writeln();
        return ExitStatus.Failure;
    }
}

const Command helpCommand = {
    primary: "help", secondary: "?", blurb: "Display help topics", helpText: "Display help topics",
    exec: &helpExecute,
};
