/*
 * This file is part of moss.
 *
 * Copyright © 2020 Serpent OS Developers
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

module moss.format.binary.index;

public import std.stdint;

/**
 * An IndexEntry identifies a unique file within the file payload.
 * It records the size of the file - along with the number of times
 * the file is used within the package (deduplication statistics).
 *
 * The length refers to the *value* length of the IndexEntry, i.e. how
 * long the name is.
 */
extern (C) struct IndexEntry
{
align(1):

    /** File size, in bytes */
    uint64_t size; /* 8 bytes */

    uint64_t start; /* 8 bytes */
    uint64_t end; /* 8 bytes */

    /* Length of the name/ID */
    uint16_t length; /* 2 bytes */

    /** How many times this file is used in the package */
    uint32_t refcount; /* 4 bytes */

    ubyte[2] padding; /* 2 bytes */

    /**
     * Encode the Header to the underlying file stream
     */
    final void encode(ref ubyte[] p) @trusted nothrow
    {

        p ~= (cast(ubyte*)&size)[0 .. size.sizeof];
        p ~= (cast(ubyte*)&start)[0 .. start.sizeof];
        p ~= (cast(ubyte*)&end)[0 .. end.sizeof];
        p ~= (cast(ubyte*)&length)[0 .. length.sizeof];
        p ~= (cast(ubyte*)&refcount)[0 .. refcount.sizeof];
        p ~= padding;
    }
}

static assert(IndexEntry.sizeof == 32,
        "IndexEntry size must be 32 bytes, not " ~ IndexEntry.sizeof.stringof ~ " bytes");
