/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.cli.index
 *
 * Generate a flat colection index
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.cli.index;

public import moss.core.cli;

import std.experimental.logger;
import std.string : format;
import std.stdio : File;
import std.file : exists, isDir, dirEntries, SpanMode;
import std.algorithm : filter, sort;
import std.range : take;
import std.array : array;

import moss.format.binary.payload.meta;
import moss.format.binary.reader;
import moss.format.binary.writer;

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

        () @trusted {
            foreach (entry; dirEntries(indexDir, "*.stone", SpanMode.depth, false).filter!(
                    (i) => i.isFile))
            {
                auto r = new Reader(File(entry.name, "r"));
                scope (exit)
                {
                    r.close();
                }
                MetaPayload current = r.payload!MetaPayload;
                immutable pkgName = current.getName;
                if (current is null)
                {
                    fatal("NO PAYLOAD");
                    return;
                }
                MetaPayload existing;
                if (pkgName in payloads)
                {
                    existing = payloads[pkgName];
                }
                if (existing !is null)
                {
                    immutable oldRel = existing.getRelease;
                    immutable newRel = existing.getRelease;
                    if (oldRel == newRel)
                    {
                        fatal(format!"Trying to include two packages with same release number: %s - %s"(
                                existing.getPkgID, current.getPkgID));
                    }
                    /* Old release trumps new release */
                    if (oldRel > newRel)
                    {
                        continue;
                    }
                }
                current.addRecord(RecordType.String, RecordTag.PackageHash, hash);
                current.addRecord(RecordType.String, RecordTag.PackageURI, uri);
                current.addRecord(RecordType.String, RecordTag.PackageSize, size);
                payloads[pkgName] = current;
            }
        }();

        auto keys = () @trusted {
            auto keySet = payloads.keys.array;
            keySet.sort!((a, b) => a < b);
            return keySet;
        }();

        auto w = new Writer(File("stone.index", "w"));
        w.compressionType = PayloadCompression.Zstd;
        w.fileType = MossFileType.Repository;

        foreach (pkgName; keys)
        {
            auto payload = payloads[pkgName];
            w.addPayload(payload);
        }

        w.close();

        return 0;
    }
}
