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

module moss.db.cachedb;

public import moss.db : MossDB;
public import serpent.ecs : EntityManager;
public import moss.format.binary.payload.kvpair;
import std.path : buildPath;
import std.stdint : uint16_t;

/**
 * Current version of the Cache Payload
 */
const uint16_t cachePayloadVersion = 1;

/**
 * CacheDB is a specialised implementation of MossDB that simply stores the
 * reference count of every asset utilised. The eventual notion is when a refcount
 * hits 0, the asset must be deleted from disk.
 */
public final class CacheDB : MossDB
{
    @disable this();

    /**
     * Construct a new CacheDB using the given EntityManager
     */
    this(EntityManager entityManager)
    {
        super(entityManager);
        filePath = buildPath("/moss/db/cachedb");
    }
}

/**
 * The CachePayload is a specialised KvPairPayload that handles
 * encoding/decoding of the CacheDB to and from a moss archive
 */
public final class CachePayload : KvPairPayload
{

    /**
     * Construct a new CachePayload
     */
    this()
    {
        super(PayloadType.CacheDB, cachePayloadVersion);
    }

    static this()
    {
        import moss.format.binary.reader : Reader;

        Reader.registerPayloadType!CachePayload(PayloadType.CacheDB);
    }
}
