/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.cli.inspect_command
 *
 * The inspect command is used to inspect the payload of a .stone package.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.cli.inspect_command;

public import moss.core.cli;
import moss.core;
import moss.deps.dependency;
import moss.format.binary.reader;
import moss.format.binary.payload;
import std.exception : enforce;
import std.format : format;
import std.stdio;

/**
 * InspectCommand is used to inspect the payload of an archive
 */
@CommandName("inspect")
@CommandHelp("Inspect contents of a .stone file",
        "With a locally available .stone file, this command will attempt to
read, validate and extract information on the given package.
If the file is not a valid .stone file for moss, an error will be
reported.")
@CommandUsage("[.stone file]")
public struct InspectCommand
{
    /** Extend BaseCommand with Inspect utility */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the InspectCommand utility
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
            stderr.writefln!"No such package: %s"(packageName);
            return;
        }

        auto reader = new Reader(File(packageName, "rb"));

        stdout.writefln!"Archive: %s"(packageName);

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
            stdout.writefln!"Payload: %s [Records: %d Compression: %s, Savings: %.2f%%, Size: %s]"(
                    to!string(hdr.type),
                    hdr.numRecords, to!string(hdr.compression), savings, puncomp);
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
        import moss.format.binary.payload.meta : MetaPayload, RecordTag, RecordType;
        import std.conv : to;

        auto metadata = cast(MetaPayload) p;
        foreach (pair; metadata)
        {
            writefln!"%-15s : "(pair.tag.to!string);

            /* TODO: Care more about other values :)) */
            switch (pair.type)
            {
            case RecordType.Int8:
                writeln(pair.get!int8_t);
                break;
            case RecordType.Uint64:
                if (pair.tag == RecordTag.PackageSize)
                {
                    writeln(formatBytes(pair.get!uint64_t));
                }
                else
                {
                    writeln(pair.get!uint64_t);
                }
                break;
            case RecordType.String:
                writeln(pair.get!string);
                break;
            case RecordType.Dependency:
                writeln(pair.get!Dependency);
                break;
            case RecordType.Provider:
                writeln(pair.get!Provider);
                break;
            default:
                writefln!"Unsupported value type: %s"(pair.type);
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

        foreach (entry; layout)
        {
            switch (entry.entry.type)
            {
            case FileType.Regular:
                writefln!"  - /usr/%s -> %s [%s]"(entry.target,
                        entry.digestString(), to!string(entry.entry.type));
                break;
            case FileType.Symlink:
                writefln!"  - /usr/%s -> %s [%s]"(entry.target,
                        entry.symlinkSource(), to!string(entry.entry.type));
                break;
            default:
                writefln!"  - /usr/%s [%s]"(entry.target, to!string(entry.entry.type));
                break;
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
        foreach (entry; index)
        {
            writefln!"  - %s [size: %9s]"(cast(string) entry.digestString(),
                    formatBytes(entry.contentSize));
        }
    }

    /**
     * Convert bytes to a pretty, condensed version
     */
    string formatBytes(const float bytes) pure @safe
    {
        /* Sensible invariant */
        enforce(bytes >= 0,
                format!"formatBytes was called with a negative size argument (%.2f)"(bytes));

        float divisor;
        string unitSI;
        ubyte decimals = 2;

        /* Comparisons are faster than floating point division */
        if (bytes >= 1_000_000_000)
        {
            divisor = 1_000_000_000;
            unitSI = "GB";
        }
        else if (bytes >= 1_000_000)
        {
            divisor = 1_000_000;
            unitSI = "MB";
        }
        else if (bytes >= 1_000)
        {
            divisor = 1_000;
            unitSI = "KB";
        }
        /* bytes don't have decimals*/
        else
        {
            divisor = 1;
            unitSI = "B ";
            decimals = 0;
        }

        /* we want the format string checked at compile time, tyvm */
        return format!"%.*f %s"(decimals, bytes / divisor, unitSI);
    }
}
