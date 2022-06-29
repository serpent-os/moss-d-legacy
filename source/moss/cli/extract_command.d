/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.cli.extract_command
 *
 * Extract moss .stone package contents without installation.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.cli.extract_command;

public import moss.core.cli;
import moss.core;
import moss.format.binary.reader;
import moss.format.binary.payload;
import std.stdio : writeln, writefln, stderr, stdout;
import moss.core.ioutil;
import std.sumtype : tryMatch;

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
        import moss.format.binary.payload.layout : LayoutPayload, EntrySet;
        import std.exception : enforce;
        import std.array : join;
        import std.file : mkdir, remove, mkdirRecurse;

        if (!packageName.exists())
        {
            stderr.writefln!"No such package: %s"(packageName);
            return;
        }

        auto reader = new Reader(File(packageName, "rb"));

        stdout.writefln!"Extracting package: %s"(packageName);

        auto extractionDir = join([".", "mossExtraction"], "/");
        auto installDir = join([".", "mossInstall/usr"], "/");
        if (!extractionDir.exists)
        {
            extractionDir.mkdir();
        }
        auto contentFile = join([extractionDir, "MOSSCONTENT"], "/");
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
        void extractIndex(ref IndexEntry entry)
        {
            auto id = cast(string) entry.digestString();
            import std.conv : to;
            import std.range : chunks;
            import std.algorithm : each;

            /* Copy file to targets. */
            auto fileName = join([extractionDir, id], "/");

            auto targetFile = File(fileName, "wb");
            auto copyableRange = cast(ubyte[]) mappedFile[entry.start .. entry.end];
            copyableRange.chunks(4 * 1024 * 1024).each!((b) => targetFile.rawWrite(b));
            targetFile.close();
        }

        void applyLayout(ref EntrySet entry, const(string) target)
        {
            import std.string : startsWith;
            import moss.core : FileType;
            import std.file : setAttributes;
            import std.path : dirName;

            auto targetPath = join([
                installDir, target.startsWith("/") ? target[1 .. $]: target
            ], "/");
            writefln!"Constructing target: %s"(targetPath);

            switch (entry.entry.type)
            {
            case FileType.Directory:
                /* Construct the directory */
                targetPath.mkdirRecurse();
                targetPath.setAttributes(entry.entry.mode);
                break;
            case FileType.Regular:
                targetPath.dirName.mkdirRecurse();
                /* Link to final destination */
                const auto sourcePath = join([extractionDir, entry.digestString], "/");
                auto res = IOUtil.hardlink(sourcePath, targetPath);
                res.tryMatch!((bool b) => b);
                targetPath.setAttributes(entry.entry.mode);
                break;
            case FileType.Symlink:
                targetPath.dirName.mkdirRecurse();
                import std.file : symlink;

                symlink(entry.symlinkSource, targetPath);
                break;
            default:
                stderr.writeln("Extraction support not yet complete");
                break;
            }
        }

        installDir.mkdirRecurse();

        indexPayload.each!((entry) => extractIndex(entry));
        layoutPayload.each!((e) => applyLayout(e, e.target));
    }
}
