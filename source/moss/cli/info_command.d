/*
 * This file is part of moss.
 *
 * Copyright © 2020-2021 Serpent OS Developers
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

module moss.cli.info_command;

public import moss.core.cli;
import moss.core;
import moss.format.binary.reader;
import std.stdio;

/**
 * InfoCommand provides a CLI system to view information
 * pertaining to a package or local package file, as a
 * means of introspection
 */
@CommandName("info")
@CommandHelp("Display information on a package",
        "With a locally available .stone file, this command will attempt to
read, validate and extract information on the given package.
If the file is not a valid .stone file for moss, an error will be
reported.")
@CommandUsage("[.stone file]")
public struct InfoCommand
{
    /** Extend BaseCommand with Info utility */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the InfoCommand utility
    */
    @CommandEntry() int run(ref string[] argv)
    {
        import std.algorithm : each;

        if (argv.length < 1)
        {
            stderr.writeln("Requires an argument");
            return ExitStatus.Failure;
        }

        argv.each!((a) => readPackage(a));
        return ExitStatus.Success;
    }

    /**
     * Helper to read each package
     */
    void readPackage(string packageName)
    {
        import std.file : exists;
        import std.conv : to;

        if (!packageName.exists())
        {
            stderr.writeln("No such package: ", packageName);
            return;
        }

        auto reader = new Reader(File(packageName, "rb"));

        writeln("Package: ", packageName);

        import moss.format.binary.payload.meta : MetaPayload, RecordType;

        auto metadata = reader.payload!MetaPayload();
        foreach (pair; metadata)
        {
            writef("%-15s : ", pair.tag.to!string);

            /* TODO: Care more about signed values :)) */
            if (pair.type == RecordType.String)
            {
                writeln(pair.val_string);
            }
            else
            {
                writeln(pair.val_i64);
            }
        }
        writeln();

        /* Grab index */
        import moss.format.binary.payload.index : IndexPayload;

        auto indices = reader.payload!IndexPayload();
        if (indices !is null)
        {
            writeln(indices);
        }
    }
}
