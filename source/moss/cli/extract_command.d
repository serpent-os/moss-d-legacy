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
import std.stdio : writeln, stderr;

/**
 * The ExtractCommand provides a CLI system to extract moss
 * packages to a given directory without installation
 */
@CommandName("extract")
@CommandHelp("Extract a local package to the working directory")
@CommandAlias("xf")
@CommandUsage("[.stone file]")
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
        import moss.format.binary.payload.layout : LayoutPayload, LayoutEntry;
        import std.exception : enforce;
        import std.path : buildPath;
        import std.file : mkdir, remove, mkdirRecurse;

        if (!packageName.exists())
        {
            stderr.writeln("No such package: ", packageName);
            return;
        }

        auto reader = new Reader(File(packageName, "rb"));

        writeln("Extracting package: ", packageName);

        auto extractionDir = ".".buildPath("mossExtraction");
        auto installDir = ".".buildPath("mossInstall");
        if (!extractionDir.exists)
        {
            extractionDir.mkdir();
        }
        auto contentFile = extractionDir.buildPath("MOSSCONTENT");
        scope (exit)
        {
            contentFile.remove();
        }

        auto contentPayload = reader.payload!ContentPayload;
        auto layoutPayload = reader.payload!LayoutPayload;
        auto indexPayload = reader.payload!IndexPayload;

        enforce(contentPayload !is null, "ContentPayload not present");
        enforce(indexPayload !is null, "IndexPayload not present");
        enforce(layoutPayload !is null, "LayoutPayload not present");

        import std.algorithm : each;

        /** TODO: Use better filename! */
        reader.unpackContent(contentPayload, contentFile);

        import std.mmfile : MmFile;

        auto mappedFile = new MmFile(File(contentFile, "rb"));

        /**
         * Inefficient extraction of indices via copying. Eventually we'll
         * support copy_file_range which will minimise userspace copying and
         * do much of it in kernel space.
         *
         * Our current version read/writes in 4MB chunks.
         */
        void extractIndex(ref IndexEntry entry, const(string) id)
        {
            import std.conv : to;
            import std.range : chunks;
            import std.algorithm : each;

            /* Copy file to targets. */
            auto fileName = extractionDir.buildPath(id);

            auto targetFile = File(fileName, "wb");
            auto copyableRange = cast(ubyte[]) mappedFile[entry.start .. entry.end];
            copyableRange.chunks(4 * 1024 * 1024).each!((b) => targetFile.rawWrite(b));
            targetFile.close();
        }

        void applyLayout(ref LayoutEntry entry, const(string) source, const(string) target)
        {
            import std.stdio : writefln;
            import std.string : startsWith;
            import moss.core : FileType;

            auto targetPath = installDir.buildPath(target.startsWith("/") ? target[1 .. $] : target);
            writefln("Constructing target: %s", targetPath);

            void updateAttrs()
            {
                import std.file : setAttributes, setTimes;
                import std.datetime : SysTime;

                targetPath.setAttributes(entry.mode);
                targetPath.setTimes(SysTime.fromUnixTime(entry.time),
                        SysTime.fromUnixTime(entry.time));
            }

            switch (entry.type)
            {
            case FileType.Directory:
                /* Construct the directory */
                targetPath.mkdirRecurse();

                /* Directory access changes as it needs applying in reverse. Revisit */
                updateAttrs();
                break;
            case FileType.Regular:
                /* Link to final destination */
                const auto sourcePath = extractionDir.buildPath(source);
                import moss.core.util : hardLink;
                import std.file : setAttributes;

                hardLink(sourcePath, targetPath);

                updateAttrs();
                break;
            case FileType.Symlink:
                import std.file : symlink;

                symlink(source, targetPath);
                break;
            default:
                stderr.writeln("Extraction support not yet complete");
                break;
            }
        }

        installDir.mkdirRecurse();

        indexPayload.each!((entry, id) => extractIndex(entry, id));
        layoutPayload.each!((e) => applyLayout(e.entry, e.source, e.target));
    }
}
