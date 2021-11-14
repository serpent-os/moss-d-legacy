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
import moss.format.binary.payload;
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

        writeln("Archive: ", packageName);

        /**
         * Emit all headers
         */
        foreach (hdr; reader.headers)
        {
            /* Calculate compression savings */
            immutable float comp = hdr.storedSize;
            immutable float uncomp = hdr.plainSize;
            auto puncomp = formatBytes(uncomp);
            auto savings = (comp > 0 ? (100.0f - (comp / uncomp) * 100.0f) : 0);
            writefln("Payload: %s [Records: %d Compression: %s, Savings: %.2f%%, Size: %s]",
                    to!string(hdr.type), hdr.numRecords,
                    to!string(hdr.compression), savings, puncomp);
            switch (hdr.type)
            {
            case PayloadType.Meta:
                printMeta(hdr.payload);
                break;
            case PayloadType.Layout:
                printLayout(hdr.payload);
                break;
            case PayloadType.Index:
                printIndex(hdr.payload);
                break;
            default:
                break;
            }
        }
    }

    /**
     * Print all metadata in a local package file
     */
    void printMeta(scope Payload p)
    {
        import moss.format.binary.payload.meta : MetaPayload, RecordType;
        import std.conv : to;

        auto metadata = cast(MetaPayload) p;
        foreach (pair; metadata)
        {
            writef("%-15s : ", pair.tag.to!string);

            /* TODO: Care more about other values :)) */
            switch (pair.type)
            {
            case RecordType.Int8:
                writeln(pair.get!int8_t);
                break;
            case RecordType.Uint64:
                writeln(pair.get!uint64_t);
                break;
            case RecordType.String:
                writeln(pair.get!string);
                break;
            default:
                writeln("Unsupported value type: ", pair.type);
                break;
            }
        }
        writeln();
    }

    /**
     * Print all layout information in a local package file
     */
    void printLayout(scope Payload p)
    {
        /* Grab layout */
        import moss.format.binary.payload.layout : LayoutPayload;

        auto layout = cast(LayoutPayload) p;
        import std.conv : to;

        foreach (entry, source, target; layout)
        {
            if (source !is null)
            {
                writefln("  - %s -> %s [%s]", target, source, to!string(entry.type));
            }
            else
            {
                writefln("  - %s [%s]", target, to!string(entry.type));
            }
        }
    }

    /**
     * Print all index entries within the payload
     */
    void printIndex(scope Payload p)
    {
        import moss.format.binary.payload.index : IndexPayload;

        auto index = cast(IndexPayload) p;
        foreach (entry, id; index)
        {
            writefln("  - %s [size: %9s]", id, formatBytes(entry.size));
        }
    }

    /**
     * Convert bytes to a pretty condensed version
     */
    string formatBytes(float bytes)
    {
        import std.format : format;

        const string[4] units = ["B ", "KB", "MB", "GB"];
        const int[4] deci = [0, 2, 2, 2];
        const auto k = 1000;

        for (int i = 3; i >= 0; i--)
        {
            auto correctsize = bytes / (k ^^ i);
            if (correctsize > 1)
            {
                return "%.*f %s".format(deci[i], correctsize, units[i]);
            }
        }
        assert(0);
    }
}
