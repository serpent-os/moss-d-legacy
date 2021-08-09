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

module moss.client.direct;

import moss.context;
import std.exception : enforce;
import std.file : exists;

public import moss.client : MossClient;

import moss.core : hardLink;

import moss.storage.pool;
import moss.storage.db.layoutdb;
import moss.storage.db.statedb;

import moss.format.binary.payload.index;
import moss.format.binary.payload.layout;
import moss.format.binary.payload.meta;
import moss.format.binary.payload.content;
import moss.format.binary.reader;

import std.mmfile;

/**
 * The direct implementation for MossClient
 *
 * This (default) implementation works directly on the local filesystems
 * and has no broker mechanism
 */
public final class DirectMossClient : MossClient
{

    /**
     * Construct a new Direct moss client
     */
    this() @trusted
    {
        enforce(context.paths.root !is null, "context.paths.root() is null!");
        enforce(context.paths.root.exists, "context.paths.root() does not exist!");

        /* Enforce creation of all required paths */
        context.paths.mkdirs();

        /* Construct our DBs.. */
        layoutDB = new LayoutDB();
        stateDB = new StateDB();
        pool = new DiskPool();
    }

    /**
     * Install some .stone files on the CLI
     */
    override void installLocalArchives(string[] archivePaths)
    {
        import std.stdio : writefln;
        import std.string : format;
        import std.array : array;
        import std.algorithm : each, canFind, map;

        auto stateOld = stateDB.lastState();
        auto stateNew = State(stateDB.nextStateID(),
                "Installation of %d packages".format(archivePaths.length), null);
        auto oldSelections = stateDB.entries(stateOld.id).array();

        /* Anything to do? */
        if (oldSelections.length == 0 && archivePaths.length == 0)
        {
            return;
        }

        /* Precache assets */
        auto newCandidates = archivePaths.map!((p) => precacheArchive(p)).array();
        enforce(!newCandidates.canFind(null) && !newCandidates.canFind(""),
                "Failure in precacheAssets");
        import std.stdio : writeln;

        writeln(newCandidates);

        /* Persist old selections. */
        oldSelections.each!((sel) => stateDB.markSelection(stateNew.id, sel));

        /* Store new State */
        stateDB.addState(stateNew);

        /* Mark installed in new state */
        newCandidates.each!((e) => stateDB.markSelection(stateNew.id,
                Selection(e, SelectionReason.ManuallyInstalled)));
        constructRootSnapshot(stateNew);
    }

    override void close()
    {
        layoutDB.close();
        stateDB.close();
    }

private:

    void extractIndex(MmFile mappedFile, ref IndexEntry entry, const(string) id)
    {
        import std.conv : to;
        import std.range : chunks;
        import std.algorithm : each;
        import std.path : dirName;
        import std.file : mkdirRecurse;

        if (pool.contains(id))
        {
            return;
        }

        /* Copy file to targets. */
        auto fileName = pool.fullPath(id);
        auto dirPath = fileName.dirName();
        dirPath.mkdirRecurse();

        auto targetFile = File(fileName, "wb");
        auto copyableRange = cast(ubyte[]) mappedFile[entry.start .. entry.end];
        copyableRange.chunks(4 * 1024 * 1024).each!((b) => targetFile.rawWrite(b));
        targetFile.close();
    }

    /**
     * Introduce assets into the store, return the candidate ID
     */
    string precacheArchive(const(string) path)
    {
        import std.stdio : writefln;
        import std.file : exists;

        auto pkgFile = File(path, "rb");
        auto reader = new Reader(pkgFile);
        writefln("Caching: %s", path);

        /* Must exist first.. */
        if (!path.exists)
        {
            return null;
        }

        auto metaPayload = reader.payload!MetaPayload;
        auto payload = reader.payload!LayoutPayload;
        auto indexPayload = reader.payload!IndexPayload;
        auto contentPayload = reader.payload!ContentPayload;

        enforce(payload !is null, "Should have a LayoutPayload..");
        enforce(metaPayload !is null, "Should have a MetaPayload..");

        string pkgName = null;
        uint64_t pkgRelease = 0;
        string pkgVersion = null;
        string pkgArchitecture = null;

        import std.algorithm : each;

        metaPayload.each!((t) => {
            switch (t.tag)
            {
            case RecordTag.Name:
                pkgName = t.val_string;
                break;
            case RecordTag.Release:
                pkgRelease = t.val_u64;
                break;
            case RecordTag.Version:
                pkgVersion = t.val_string;
                break;
            case RecordTag.Architecture:
                pkgArchitecture = t.val_string;
                break;
            default:
                break;
            }
        }());

        import std.string : format;

        /* Unpack to the cache directory */
        auto pkgIDName = "%s-%s-%d.%s".format(pkgName, pkgVersion, pkgRelease, pkgArchitecture);
        auto contentFile = context.paths.cache.buildPath("content-%s".format(pkgIDName));
        reader.unpackContent(contentPayload, contentFile);

        /** Memory map the content file */
        auto mappedFile = new MmFile(File(contentFile, "rb"));
        scope (exit)
        {
            mappedFile.destroy();
        }

        /* Extract all index files from content, install layout payload */
        indexPayload.each!((entry, id) => extractIndex(mappedFile, entry, id));
        layoutDB.installPayload(pkgIDName, payload);

        return pkgIDName;
    }

    /**
    * Construct root snapshot for the given identifier
    */
    void constructRootSnapshot(ref State newState)
    {
        import std.algorithm : sort, uniq, map, each;
        import std.array : array, join;
        import std.stdio : writeln;

        /* Copy all installed candidates */
        auto installedCandidates = stateDB.entries(newState.id).array();
        auto finalLayouts = installedCandidates.map!((s) => layoutDB.entries(s.target)).join;
        finalLayouts.sort!((esA, esB) => esA.target < esB.target);

        /* Build set of layouts for all candidates */
        import std.stdio : writeln;

        writeln(" => Beginning filesystem blit");
        finalLayouts.uniq!((esA, esB) => esA.target == esB.target)
            .each!((es) => applyLayout(newState, es));
        writeln(" => Ended filesystem blit");
    }

    void applyLayout(ref State newState, ref EntrySet es)
    {
        import std.path : buildPath;
        import std.conv : to;

        /* /.moss/store/root/1 .. */
        auto targetNode = context.paths.store.buildPath("root",
                to!string(newState.id), es.target[1 .. $]);

        import moss.format.binary : FileType;
        import std.file : mkdirRecurse, symlink;

        /* Update attributes on the layout item. */
        void updateAttrs()
        {
            import std.file : setAttributes, setTimes;
            import std.datetime : SysTime;

            targetNode.setAttributes(es.entry.mode);
            targetNode.setTimes(SysTime.fromUnixTime(es.entry.time),
                    SysTime.fromUnixTime(es.entry.time));
        }

        /* Handle basic file types now */
        switch (es.entry.type)
        {
        case FileType.Directory:
            targetNode.mkdirRecurse();
            updateAttrs();
            break;
        case FileType.Symlink:
            es.source.symlink(targetNode);
            break;
        case FileType.Regular:
            auto sourcePath = pool.fullPath(es.source);
            hardLink(sourcePath, targetNode);
            updateAttrs();
            break;
        default:
            break;
        }
    }

    LayoutDB layoutDB = null;
    StateDB stateDB = null;
    DiskPool pool = null;
}
