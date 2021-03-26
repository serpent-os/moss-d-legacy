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

module moss.db.disk;

import std.exception : enforce;
import std.path : buildPath;
import std.stdio : File;

/**
 * The DiskDB is a very inefficient method for encoding data in a permanent
 * fashion to permit upgrading between DB formats and layouts over time, without
 * losing any information.
 *
 * It is the backup solution in the absence of a usable database.
 */
final class DiskDB
{
    @disable this();

    /**
     * Construct a new DiskDB with the given system root and DB name
     */
    this(const(string) systemRoot, const(string) dbName)
    {
        _systemRoot = systemRoot;
        _dbName = dbName;

        enforce(systemRoot !is null, "DiskDB(): Cannot operate on NULL systemRoot");
        enforce(dbName !is null, "DiskDB(): Cannot operate on NULL dbName");

        /* Raw DB path for DiskDB */
        _dbPath = systemRoot.buildPath("moss", "db", dbName, "raw");
    }

    /**
     * Return the systemRoot property
     */
    pure @property const(string) systemRoot() @safe @nogc nothrow
    {
        return _systemRoot;
    }

    /**
     * Return the dbName property
     */
    pure @property const(string) dbName() @safe @nogc nothrow
    {
        return _dbName;
    }

    /**
     * Return the database path on disk
     */
    pure @property const(string) dbPath() @safe @nogc nothrow
    {
        return _dbPath;
    }

    /**
     * Set the contents of key to contents
     */
    void setContents(const(string) key, ubyte[] contents) @system
    {
        const filePath = dbPath.buildPath(key);

        File fi = File(filePath, "wb");
        scope (exit)
        {
            fi.close();
        }
        fi.rawWrite(contents);
    }

    /**
     * Return the contents of the given key
     */
    ubyte[] getContents(const(string) key)
    {
        const filePath = dbPath.buildPath(key);
        import std.file : read, exists;

        if (!filePath.exists)
        {
            return null;
        }
        return cast(ubyte[]) read(filePath);
    }

    /**
     * Remove key from the database
     */
    void removeKey(const(string) key)
    {
        const filePath = dbPath.buildPath(key);
        import std.file : remove;

        remove(filePath);
    }

private:

    string _systemRoot = "/";
    string _dbName = null;
    string _dbPath = null;
}
