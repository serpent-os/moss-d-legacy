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

module moss.storage.db.packagesdb;

import moss.context;
import moss.db;
import moss.db.rocksdb;
import moss.format.binary.payload.meta;
import std.stdint : uint64_t;
import std.string : format;
import std.exception : enforce;
import std.typecons : Nullable;

public import moss.deps.registry.plugin;

/**
 * SystemPackagesDB tracks packages installed across various states and doesn't specifically
 * link them to any given state. Instead it retains MetaData for locally installed
 * candidates to provide a system level of resolution for packages no longer referenced
 * from a repository.
 */
public final class SystemPackagesDB
{
    /**
     * Construct a new SystemPackagesDB which will immediately force a reload of the
     * on-disk database if it exists
     */
    this()
    {
        reloadDB();
    }

    ~this()
    {
        close();
    }

    /**
     * Ensure we close underlying handle
     */
    void close()
    {
        if (db is null)
        {
            return;
        }
        db.close();
        db.destroy();
        db = null;
    }

    /**
     * Forcibly reload the database
     */
    void reloadDB()
    {
        if (db !is null)
        {
            db.close();
            db.destroy();
            db = null;
        }

        /* Recreate DB now */
        const auto path = context().paths.db.buildPath("packagesDB");
        db = new RDBDatabase(path, DatabaseMutability.ReadWrite);
    }

    /**
     * Install the given payload into our system. It is keyed by the
     * unique pkgID, so we can only retain a single payload per pkgID
     * and increase/decrease refcount as appropriate.
     */
    string installPayload(MetaPayload payload)
    {
        return null;
    }

    /**
     * Set an explicit refCount for the pkgID
     */

private:

    Database db = null;
}
