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

module moss.format.binary.indexPayload;

import moss.format.binary.endianness;
import moss.format.binary.encoder;
import moss.format.binary.payload;

public import std.stdio : File, FILE;
public import moss.format.binary.index;

const uint16_t IndexPayloadVersion = 1;

/**
 * The IndexPayload maps offsets within the Content payload with their
 * names, so it can be unpacked onto disk.
 */
struct IndexPayload
{

public:

    Payload pt;
    alias pt this;

    /**
     * Ensure default initialisation is not insane.
     */
    static IndexPayload opCall()
    {
        IndexPayload r;
        r.type = PayloadType.Layout;
        r.compression = PayloadCompression.None;
        r.payloadVersion = IndexPayloadVersion;
        r.length = 0;
        r.size = 0;
        r.numRecords = 0;
        return r;
    }

    /**
     * Handle encoding datum
     */
    final void addEntry(ref IndexEntry entry, string name) @trusted
    {
        import std.string : toStringz;

        entry.length = cast(uint16_t)(name.length + 1); /* + nul terminator */

        entry.encode(binary);
        numRecords++;

        auto z = toStringz(name);
        binary ~= (cast(ubyte*) z)[0 .. entry.length];
    }

    /**
     * Encode our data to the archive
     */
    final void encode(scope FILE* fp)
    {
        encodePayloadBuffer(fp, this, binary);
    }

private:

    ubyte[] binary;
}
