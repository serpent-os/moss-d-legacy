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

module moss.cli.extract_command;

public import moss.core.cli;
import moss.core;
import moss.format.binary.reader;
import moss.format.binary.payload;
import std.stdio : writeln, writefln, stderr;

/**
 * The ExtractCommand provides a CLI system to extract moss
 * packages to a given directory without installation
 */
@CommandName("extract")
@CommandHelp("Extract a local package to the working directory")
public struct ExtractCommand
{
    /** Extend BaseCommand with extraction utility */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point for the ExtractCommand
     */
    @CommandEntry() int run(ref string[] argv)
    {
        import std.algorithm : each;

        if (argv.length < 1)
        {
            stderr.writeln("Requires an argument");
            return ExitStatus.Failure;
        }

        argv.each!((a) => unpackPackage(a));
        return ExitStatus.Success;
    }

    /**
     * Handle unpacking of a single package
     */
    void unpackPackage(const(string) packageName)
    {
        import std.file : exists;
        import moss.format.binary.payload.content : ContentPayload;
        import moss.format.binary.payload.index : IndexPayload, IndexEntry;
        import moss.format.binary.payload.layout : LayoutPayload;
        import std.exception : enforce;

        if (!packageName.exists())
        {
            stderr.writeln("No such package: ", packageName);
            return;
        }

        auto reader = new Reader(File(packageName, "rb"));

        writeln("Extracting package: ", packageName);

        auto contentPayload = reader.payload!ContentPayload;
        auto layoutPayload = reader.payload!LayoutPayload;
        auto indexPayload = reader.payload!IndexPayload;

        enforce(contentPayload !is null, "ContentPayload not present");
        enforce(indexPayload !is null, "IndexPayload not present");
        enforce(layoutPayload !is null, "LayoutPayload not present");

        import std.algorithm : each;

        /* Handle extraction of cache indices */
        void extractIndex(ref IndexEntry entry, const(string) id)
        {
            import std.conv : to;

            writefln("extracting entry: %s [%s]", id, to!string(entry));
        }

        indexPayload.each!((entry, id) => extractIndex(entry, id));

        /** TODO: Use better filename! */
        reader.unpackContent(contentPayload, "./MOSSCONTENT");
    }
}
