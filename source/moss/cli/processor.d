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

module moss.cli.processor;

import moss.cli : Command;
import moss.cli.helpCommand;
import std.stdio;

/**
 * The cli.Processor provides a simple subcommand oriented processing system
 * with which to dispatch and handle CLI arguments.
 */

final struct Processor
{

private:

    string[] argv;
    string name; /* CLI Name */

    /**
     * Builtin list of handlers
     */
    static const Command*[] handlers = [&helpCommand,];

    final void printUsage()
    {
        stderr.writeln("USE ME CORRECTLY");
    }

public:

    @disable this();

    /**
     * Construct a new Processor
     */
    this(string[] argv) nothrow
    {
        this.name = argv[0];
        this.argv = argv.length > 1 ? argv[1 .. $] : [];
    }

    /**
     * Process all arguments and dispatch to the right caller
     */
    final int process()
    {
        if (argv.length < 1)
        {
            printUsage();
            return 1;
        }

        /** TODO: Consume getopt */
        auto command = argv[0];
        Command* handler = null;

        foreach (const ref h; handlers)
        {
            if (h.matches(command))
            {
                handler = cast(Command*) h;
                break;
            }
        }

        if (handler is null)
        {
            stderr.writefln("Unknown command: %s", command);
            printUsage();
            return 1;
        }

        return 0;
    }
}
