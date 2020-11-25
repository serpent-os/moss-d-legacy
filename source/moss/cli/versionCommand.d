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
 * Version command implementation
 */
module moss.cli.versionCommand;
import moss.cli;
import moss.core;

static ExitStatus versionExecute(ref Processor p)
{
    import std.stdio;

    writefln("moss package manager, version %s", moss.core.Version);
    writeln("\nCopyright © 2020 Serpent OS Developers");
    writeln("Available under the terms of the ZLib license");
    return ExitStatus.Success;
}

const Command versionCommand = {
    primary: "version", secondary: null, blurb: "Show the program version and exit",
    helpText: "Show the program version and exit", exec: &versionExecute,
};
