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

module moss.db.rocksdb.db;

import rocksdb;
import moss.db.rocksdb.bucket;
import moss.db.rocksdb.transform;

public import moss.db : Datum;
public import moss.db.interfaces : Database, DatabaseMutability, IReadWritable;

/**
 * RocksDB implementation of the KBDatabase interface
 */
public class RDBDatabase : Database
{

    @disable this();

    /**
     * Construct a new RDBDatabase with the given pathURI and mutability settings
     */
    this(const(string) pathURI, DatabaseMutability mut = DatabaseMutability.ReadOnly)
    {
        super(pathURI, mut);

        /* Organise our options */
        dbOpts = new DBOptions();
        auto fact = new BlockedBasedTableOptions();
        fact.wholeKeyFiltering = false;
        fact.filterPolicy = new BloomFilterPolicy(10);
        dbOpts.blockBasedTableFactory = fact;
        dbOpts.prefixExtractor = new NamespacePrefixTransform();

        final switch (mutability)
        {
        case DatabaseMutability.ReadOnly:
            dbOpts.createIfMissing = false;
            dbOpts.errorIfExists = false;
            break;
        case DatabaseMutability.ReadWrite:
            dbOpts.createIfMissing = true;
            dbOpts.errorIfExists = false;
            break;
        }

        /* Establish the DB connection. TODO: Support read-only connections  */
        _dbCon = new rocksdb.Database(dbOpts, pathURI);
        rootBucket = new RDBBucket(this, null);
    }

    /**
     * Set a key in the root namespace
     */
    pragma(inline, true) override void set(scope Datum key, scope Datum value)
    {
        rootBucket.set(key, value);
    }

    /**
     * Get a value from the root namespace
     */
    pragma(inline, true) override Datum get(scope Datum key)
    {
        return rootBucket.get(key);
    }

    /**
     * Return a subset of the database with an explicit prefix for
     * the purposes of namespacing
     */
    override IReadWritable bucket(scope Datum prefix)
    {
        import std.algorithm : find;

        auto buckets = nests.find!((b) => b.prefix == prefix);
        if (buckets.length > 0)
        {
            return buckets[0];
        }
        auto bk = new RDBBucket(this, prefix);
        nests ~= bk;
        return bk;
    }

    /**
     * Close (permanently) all connections to RocksDB
     */
    override void close()
    {
        import std.algorithm : each;

        if (dbCon is null)
        {
            return;
        }
        nests.each!((n) => n.destroy());
        nests = [];
        rootBucket.destroy();
        rootBucket = null;
        dbCon.close();
        dbCon.destroy();
        _dbCon = null;
    }

    @property override IIterable iterator()
    {
        return rootBucket.iterator;
    }

package:

    /**
     * Return underlying connection pointer
     */
    pragma(inline, true) pure @property rocksdb.Database dbCon() @safe @nogc nothrow
    {
        return _dbCon;
    }

private:

    RDBBucket rootBucket = null;
    RDBBucket[] nests;

    rocksdb.DBOptions dbOpts;
    rocksdb.Database _dbCon = null;
}
