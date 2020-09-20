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

module moss.format.binary.encoder;

import moss.format.binary.endianness;

public import moss.format.binary.payload;
public import std.stdio : FILE;

/**
 * Utility function to encode a Payload and ubyte[] payload to the stream
 */
package void encodeLayoutBinary(scope FILE* fp, Payload us, ref ubyte[] binary)
{
    import std.stdio : fwrite;
    import std.exception : enforce;
    import std.digest.crc;

    if (us.numRecords < 0)
    {
        return;
    }

    /* Write payload header with CRC64ISO */
    CRC64ISO hash;
    us.size = binary.length; /* Decompressed size */

    switch (us.compression)
    {
    case PayloadCompression.Zlib:
        import std.zlib;

        ubyte[] comp = compress(binary);
        hash.put(comp);
        us.length = comp.length;

        us.crc64 = hash.finish();
        us.toNetworkOrder();
        us.encode(fp);

        enforce(fwrite(comp.ptr, comp[0].sizeof, comp.length,
                fp) == comp.length, "MetaPayload.encode(): Failed to write data");
        break;
    case PayloadCompression.Zstd:
        import zstd;

        ubyte[] comp = compress(binary, 8);
        hash.put(comp);
        us.length = comp.length;

        us.crc64 = hash.finish();
        us.toNetworkOrder();
        us.encode(fp);

        enforce(fwrite(comp.ptr, comp[0].sizeof, comp.length,
                fp) == comp.length, "MetaPayload.encode(): Failed to write data");
        break;
    case PayloadCompression.None:
        hash.put(binary);
        us.length = binary.length;

        us.crc64 = hash.finish();
        us.toNetworkOrder();
        us.encode(fp);

        enforce(fwrite(binary.ptr, binary[0].sizeof, binary.length,
                fp) == binary.length, "MetaPayload.encode(): Failed to write data");
        break;
    default:
        assert(0, "Unsupported compression");
    }
}
