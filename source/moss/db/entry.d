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

module moss.db.entry;

import std.bitmanip : nativeToBigEndian, bigEndianToNative;
import std.exception : enforce;
import std.stdint : uint32_t;

/**
 * A DatabaseEntry is composed of a prefix ("bucket") and a distinct key ID
 * It is used by our internal implementations to handle bucket separation
 * in instances where it is not natively supported.
 */
struct DatabaseEntry
{
    /**
     * Prefix or "bucket ID" for the entry
     */
    ubyte[] prefix;

    /**
     * Actual key without any prefix or modification
     */
    ubyte[] key;

    this(scope const(ubyte[]) prefix, scope const(ubyte[]) key)
    {
        this.prefix = cast(ubyte[]) prefix;
        this.key = cast(ubyte[]) key;
    }

    /**
     * Encode the DatabaseEntry into a prefixed key with a fixed uint32_t prefix
     * length.
     */
    pure ubyte[] encode()
    {
        uint32_t prefixLen = prefix is null ? 0 : cast(uint32_t) prefix.length;
        ubyte[uint32_t.sizeof] encodedLen = nativeToBigEndian(prefixLen);

        /* Empty prefix? */
        if (prefixLen < 1)
        {
            /* Just returning an encoded empty prefix + key */
            if (key is null)
            {
                return encodedLen.dup;
            }

            /* Return empty prefix + key */
            return encodedLen ~ key;
        }

        /* Have prefix name but no key */
        if (key is null)
        {
            return encodedLen ~ prefix;
        }

        /* Full prefix + key combination */
        return encodedLen ~ prefix ~ key;
    }

    /**
     * Decode this DatabaseEntry from the input bytes
     */
    void decode(scope ubyte[] input)
    {
        enforce(input.length > uint32_t.sizeof, "DatabaseEntry.decode(ubyte[]): Key is too short");

        ubyte[uint32_t.sizeof] prefixLenEnc = input[0 .. uint32_t.sizeof];
        const uint32_t prefixLen = bigEndianToNative!(uint32_t, uint32_t.sizeof)(prefixLenEnc);

        static const auto prefixA = uint32_t.sizeof;
        const auto prefixB = prefixLen + uint32_t.sizeof;

        this.prefix = input[prefixA .. prefixB];
        this.key = input[prefixB .. $];
    }
}
