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

module moss.db.rocksdb.transform;

public import rocksdb.slicetransform;

import std.bitmanip : bigEndianToNative;
import std.stdint : uint32_t;
import moss.db.entry;

/**
 * This utility class is responsible for extracting the correct
 * prefix from a specially encoded key to allow bucket behaviour
 * with RocksDB.
 */
public class NamespacePrefixTransform : SliceTransform
{

    /**
     * Construct a new NamespacePrefixTransform
     */
    this()
    {
        super("moss-transform");
    }

    /**
     * Returns true if we detect a special prefix encoding
     */
    override bool inDomain(const Slice inp)
    {
        if (inp.l <= uint32_t.sizeof)
        {
            return false;
        }

        ubyte[uint32_t.sizeof] prefixLenEnc = cast(ubyte[]) inp.p[0 .. uint32_t.sizeof];
        uint32_t prefixLen = bigEndianToNative!(uint32_t, uint32_t.sizeof)(prefixLenEnc);
        return prefixLen > 0;
    }

    /**
     * Return the encoded prefix name from the full key name
     */
    override Slice transform(const Slice inp)
    {
        auto dbe = DatabaseEntry();
        ubyte[] rangedData = cast(ubyte[]) inp.p[0 .. inp.l];
        dbe.decode(rangedData);

        return Slice.fromChar(dbe.prefix.length, cast(char*) dbe.prefix);
    }

    /**
     * Defunct API - needs removing.
     */
    override bool inRange(const Slice inp)
    {
        return false;
    }
}
