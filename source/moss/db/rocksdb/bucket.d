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

module moss.db.rocksdb.bucket;

public import moss.db.interfaces : IReadWrite, IIterator;

import moss.db.entry;
import moss.db.rocksdb.db : RDBDatabase;

/**
 * In our rocksdb wrapper we have the root bucket, which may be nested, or
 * the actual nested bucket. In either case it is the root buckets job to
 * perform the real meat of the operations.
 */
package class RDBBucket : IReadWrite
{
    @disable this();

    /**
     * Return a new RDBBucket with the given prefix
     */
    this(RDBDatabase parentDB, scope ubyte[] prefix)
    {
        this._prefix = prefix;
        this.parentDB = parentDB;
    }

    override void set(scope ubyte[] key, scope ubyte[] value)
    {
        auto dbe = DatabaseEntry(prefix, key);
        parentDB.dbCon.put(dbe.encode(), value);
    }

    override ubyte[] get(scope ubyte[] key)
    {
        auto dbe = DatabaseEntry(prefix, key);
        return parentDB.dbCon.get(dbe.encode());
    }

    pure @property const(ubyte[]) prefix() @safe @nogc nothrow
    {
        return cast(const(ubyte[])) _prefix;
    }

    @property override IIterator iterator()
    {
        return null;
    }

private:

    ubyte[] _prefix = null;
    RDBDatabase parentDB = null;
}
