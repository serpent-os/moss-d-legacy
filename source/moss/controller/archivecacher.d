/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.controller.archivecacher
 *
 * Cache archive to MossController databases (and disk).
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.controller.archivecacher;

import moss.storage.diskpool;
import moss.storage.db.packagesdb;
import moss.storage.db.layoutdb;
import std.exception : enforce;
import std.stdio : File;
import std.file : exists, remove, mkdirRecurse;
import core.sys.posix.stdlib : mkstemp;
import std.string : format;
import std.algorithm : each;
import std.conv : to;
import std.range : chunks;
import std.path : dirName;
import std.mmfile;
import moss.format.binary.reader;
import moss.format.binary.payload.content;
import moss.format.binary.payload.meta;
import moss.format.binary.payload.index;
import moss.format.binary.payload.layout;

/**
 * Utility struct to cache an archive to the MossController DBs + disk
 */
package struct ArchiveCacher
{
    @disable this();

    /**
     * Construct a new ArchiveCacher. Should only be done by the
     * MossController
     */
    this(SystemPackagesDB packagesDB, LayoutDB layoutDB, DiskPool diskPool)
    {
        this.packagesDB = packagesDB;
        this.layoutDB = layoutDB;
        this.diskPool = diskPool;
    }

    /**
     * Cache the given archive path
     */
    void cache(const(string) path)
    {
        auto pkgFile = File(path, "rb");
        auto reader = new Reader(pkgFile);

        /* Must exist first.. */
        if (!path.exists)
        {
            return;
        }

        auto metaPayload = reader.payload!MetaPayload;
        auto payload = reader.payload!LayoutPayload;
        auto indexPayload = reader.payload!IndexPayload;
        auto contentPayload = reader.payload!ContentPayload;

        enforce(payload !is null, "Should have a LayoutPayload..");
        enforce(metaPayload !is null, "Should have a MetaPayload..");
        enforce(indexPayload !is null, "Should have an IndexPayload..");
        enforce(contentPayload !is null, "Should have a ContentPayload..");

        auto pkgID = metaPayload.getPkgID();
        enforce(pkgID !is null, "ArchiveCacher.cache(): Could not inspect MetaPayload");
        packagesDB.install(metaPayload);

        /* Get ourselves a tmpfile */
        auto tmpname = "/tmp/moss-content-%s-XXXXXX".format(pkgID);
        auto copy = new char[tmpname.length + 1];
        copy[0 .. tmpname.length] = tmpname[];
        copy[tmpname.length] = '\0';
        const int fd = mkstemp(copy.ptr);
        enforce(fd > 0, "ArchiveCacher.cache(): Failed to mkstemp()");

        /* Map the tmpfile back to path + File object */
        File fi;
        fi.fdopen(fd, "rb");
        const auto li = cast(long) copy.length;
        auto contentPath = cast(string) copy[0 .. li - 1];

        /* Unpack it now */
        reader.unpackContent(contentPayload, contentPath);

        /** Memory map the content file */
        auto mappedFile = new MmFile(fi, MmFile.Mode.read, 0, null, 0);
        scope (exit)
        {
            mappedFile.destroy();
            fi.close();
            enforce(copy.length > 1, "Runtime error: copy.length < 1");
            remove(contentPath);
        }

        /* Extract all index files from content, install layout payload */
        indexPayload.each!((entry) => extractIndex(mappedFile, entry));
        layoutDB.installPayload(pkgID, payload);
    }

private:

    void extractIndex(MmFile mappedFile, ref IndexEntry entry)
    {
        auto id = cast(string) entry.digestString();
        if (diskPool.contains(id))
        {
            return;
        }

        /* Copy file to targets. */
        auto fileName = diskPool.fullPath(id);
        auto dirPath = fileName.dirName();
        dirPath.mkdirRecurse();

        auto targetFile = File(fileName, "wb");
        auto copyableRange = cast(ubyte[]) mappedFile[entry.start .. entry.end];
        copyableRange.chunks(4 * 1024 * 1024).each!((b) => targetFile.rawWrite(b));
        targetFile.close();
    }

    SystemPackagesDB packagesDB;
    LayoutDB layoutDB;
    DiskPool diskPool;
}
