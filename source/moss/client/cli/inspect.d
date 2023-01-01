/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.inspect
 *
 * The inspect command is used to inspect the payload of a .stone package.
 *
 * FIXME: Needs to be converted to @safe !
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.inspect;

public import moss.core.cli;

import moss.client.ui;
import moss.core;
import moss.core.sizing;
import moss.deps;
import moss.format.binary.payload;
import moss.format.binary.reader;
import std.algorithm : map;
import std.exception : enforce;
import std.experimental.logger;
import std.file : exists;
import std.format : format;
import std.range : empty;
import std.stdio;
import std.string : join, wrap, endsWith, startsWith;

/**
 * InspectCommand is used to inspect the payload of an archive
 */
@CommandName("inspect")
@CommandHelp("Inspect contents of a .stone or a manifest.*.bin archive",
        "With a locally available .stone or manifest.*.bin archive, this command will
attempt to read, validate and extract information from the given archive.

If the file is not a valid .stone or manifest.*.bin moss archive, an error
will be reported.")
@CommandUsage("[.stone or manifest.*.bin]")
struct InspectCommand
{
    /**
     * Extend BaseCommand with InspectCommand utility
     */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the InspectCommand utility
     */
    @CommandEntry() int run(ref string[] argv) @safe
    {
        if (argv.length < 1)
        {
            error("moss inspect: Please supply a valid moss archive filename.");
            return 1;
        }
        foreach (arg; argv)
        {
            if (arg.endsWith(".stone") || (arg.startsWith("manifest.") && arg.endsWith(".bin")))
            {
                readPackage(arg);
            }
        }
        return 0;
    }
}

@trusted:

/**
 * Helper to read each package
 */
void readPackage(string packageName)
{
    import std.file : exists;
    import std.conv : to;

    if (!packageName.exists())
    {
        stderr.writefln!"No such file: %s"(packageName);
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
        immutable double comp = hdr.storedSize;
        immutable double uncomp = hdr.plainSize;
        /* Cast should always succeed because size is never negative */
        auto puncomp = formattedSize(uncomp);
        auto savings = (comp > 0 ? (100.0f - (comp / uncomp) * 100.0f) : 0);
        stdout.writefln!"Payload: %s [Records: %d Compression: %s, Savings: %.2f%%, Size: %s]"(to!string(hdr.type),
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
        writef!"%-15s : "(pair.tag.to!string);

        /* TODO: Care more about other values :)) */
        switch (pair.type)
        {
        case RecordType.Int8:
            writeln(pair.get!int8_t);
            break;
        case RecordType.Uint64:
            if (pair.tag == RecordTag.PackageSize)
            {
                immutable auto size = cast(double) pair.get!uint64_t;
                writeln(formattedSize(size));
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
        immutable auto entrySize = cast(double) entry.contentSize;
        stdout.writefln!"  - %s [size: %s]"(cast(string) entry.digestString(),
                formattedSize(entrySize));
    }
}
