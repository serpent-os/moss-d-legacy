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

module moss.storage.db.metadata;

import moss.db;
import moss.db.rocksdb;

/**
 * MetadataDB is used as a storage mechanism for the MetaPayload within the
 * binary packages and repository index files. Internally it relies on RocksDB
 * via moss-db for all KV storage.
 */
public final class MetadataDB
{
    @disable this();

    /**
     * Construct a new MetadataDB with the absolute database path
     */
    this(in string dbPath)
    {
        db = new RDBDatabase(dbPath, DatabaseMutability.ReadWrite);
    }

    /**
     * Users of MetadataDB should always explicitly close it to ensure
     * correct order of destruction for owned references.
     */
    void close()
    {
        if (db is null)
        {
            return;
        }
        db.close();
        db = null;
    }

private:

    Database db = null;
}
