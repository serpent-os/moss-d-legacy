/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.index
 *
 * Generate a flat colection index
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.index;

public import moss.core.cli;

import std.experimental.logger;
import std.string : format;
import std.stdio : File;
import std.file : exists, isDir, dirEntries, SpanMode;
import std.algorithm : filter, sort, map;
import std.range : take;
import std.array : array;
import std.path : relativePath, absolutePath, baseName, buildNormalizedPath, asNormalizedPath;
import std.parallelism : TaskPool;
import moss.format.binary.payload.meta;
import moss.format.binary.reader;
import moss.format.binary.writer;
import moss.core : computeSHA256;
import std.string : startsWith, endsWith;
import std.conv : to;
import std.exception : enforce;

/** 
 * Due to LDC lacking dual-context support, we convert our
 * input paths into real paths and resolved relative paths
 * for the index before processing.
 */
struct EnqueuedFile
{
    /**
     * Real path on disk
     */
    string realPath;

    /**
     * Relative to work directory
     */
    string relaPath;
}

auto getRelease(scope MetaPayload payload) @trusted
{
    auto rn = payload.filter!((r) => r.tag == RecordTag.Release).take(1);
    if (rn.empty)
    {
        fatal("Missing release number?!");
    }
    return rn.front.get!uint64_t;
}

auto getName(scope MetaPayload payload) @trusted
{
    auto pn = payload.filter!((r) => r.tag == RecordTag.Name).take(1);
    if (pn.empty)
    {
        fatal("Missing package number?!");
    }
    return pn.front.get!string;
}
/**
 * Index a collection
 */
@CommandName("index") @CommandAlias("idx") @CommandUsage("[directory of collection]") @CommandHelp(
        "Index a collection of packages", "TODO: Improve docs") struct IndexCommand
{
    BaseCommand pt;
    alias pt this;

    /**
     * Handle installation
     */
    @CommandEntry() int run(ref string[] argv) @safe
    {
        immutable indexDir = argv.length > 0 ? argv[0] : ".";

        if (!indexDir.exists)
        {
            error(format!"Cannot find directory: %s"(indexDir));
            return 1;
        }

        if (!indexDir.isDir)
        {
            error(format!"Not a directory: %s"(indexDir));
            return 1;
        }

        MetaPayload[string] payloads;
        auto wd = indexDir.absolutePath.asNormalizedPath.to!string;
        if (wd.endsWith("/"))
        {
            wd = wd[0 .. $ - 1];
        }

        /* Map all entries into something useful */
        auto tp = new TaskPool();
        tp.isDaemon = false;

        /* Find all of the stones */
        auto stones = () @trusted {
            return indexDir.dirEntries("*.stone", SpanMode.depth, false).filter!((i) => i.isFile)
                .map!((i) => EnqueuedFile(i.name, i.name.relativePath(wd)
                        .asNormalizedPath.to!string))
                .array();
        }();

        /* Map to payloads */
        auto mappedPayloads = () @trusted { return tp.amap!loadPayload(stones); }();
        tp.finish();

        /* Organise them now */
        foreach (payload; mappedPayloads)
        {
            MetaPayload existing;
            immutable pkgName = payload.getName;

            /* Displacement possible? */
            if (pkgName in payloads)
            {
                existing = payloads[pkgName];
            }
            else
            {
                payloads[pkgName] = payload;
                continue;
            }

            /* Compare oldRel + newRel */
            immutable oldRel = existing.getRelease;
            immutable newRel = payload.getRelease;
            if (oldRel == newRel)
            {
                immutable existingID = () @trusted { return existing.getPkgID(); }();
                immutable currentID = () @trusted { return payload.getPkgID(); }();
                fatal(format!"Trying to include two packages with same release number: %s - %s"(existingID,
                        currentID));
            }

            /* Old release trumps new release */
            if (oldRel > newRel)
            {
                continue;
            }

            /* Newest now, displace */
            payloads[pkgName] = payload;
        }

        if (payloads.length == 0)
        {
            warning(format!"No .stone files found in directory: %s"(indexDir));
        }

        /* Hash-Stable emission order */
        auto keys = () @trusted {
            auto keySet = payloads.keys.array;
            keySet.sort!((a, b) => a < b);
            return keySet;
        }();

        /* Write index to disk */
        immutable idxFile = wd.buildNormalizedPath("stone.index");
        auto w = new Writer(File(idxFile, "wb"));
        w.compressionType = PayloadCompression.Zstd;
        w.fileType = MossFileType.Repository;
        foreach (pkgName; keys)
        {
            auto payload = payloads[pkgName];
            w.addPayload(payload);
        }

        w.close();
        info(format!"Successfully wrote index to %s, containing %s stones."(idxFile,
                payloads.length));

        return 0;
    }

    /** 
     * Process an input .stone into a suitable MetaPayload for index emission
     * Params:
     *   file = Enqueued file for processing
     * Returns: Fully populated MetaPayload
     */
    static MetaPayload loadPayload(EnqueuedFile file) @trusted
    {
        info(format!"Indexing %s"(file.realPath));
        auto hash = computeSHA256(file.realPath, true);
        auto fi = File(file.realPath, "rb");
        scope reader = new Reader(fi);
        scope (exit)
        {
            reader.close();
            fi.close();
        }
        auto current = reader.payload!MetaPayload;
        enforce(current !is null, "Missing payload!");
        auto size = fi.size();
        current.addRecord(RecordType.String, RecordTag.PackageHash, hash);
        current.addRecord(RecordType.String, RecordTag.PackageURI, file.relaPath);
        current.addRecord(RecordType.Uint64, RecordTag.PackageSize, size);
        return current;
    }
}
