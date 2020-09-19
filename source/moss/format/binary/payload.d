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

module moss.format.binary.payload;

public import std.stdint;
import moss.format.binary.endianness;

/**
 * Specific payload type
 */
enum PayloadType : uint8_t
{
    /** Catch errors: Payload type should be known */
    Unknown = 0,

    /** The Metadata store */
    Meta = 1,

    /** File store, i.e. hash indexed */
    Content = 2,

    /** Map Files to Disk with basic UNIX permissions + types */
    Layout = 3,

    /** For indexing the deduplicated store */
    Index = 4,

    /* Attribute storage */
    Attributes = 5,
}

/**
 * A payload may optionally be compressed using some method like zstd.
 * It must be defined before the payload value is accessed. Additionally
 * the used compressionLevel must be stored to ensure third party tools
 * can reassemble the package.
 */
enum PayloadCompression : uint8_t
{
    /** Catch errors: Compression should be known */
    Unknown = 0,

    /** Payload has no compression */
    None = 1,

    /** Payload uses ZSTD compression */
    Zstd = 2,

    /** Payload uses zlib decompression */
    Zlib = 3,
}

/**
 * Payload is the root type within a moss binary package. Every payload
 * is expected to contain at least 1 record, with built-in verioning.
 */
extern (C) struct Payload
{
align(1):

    @autoEndian uint64_t length; /* 8 bytes */
    @autoEndian uint64_t size; /* 8 bytes */
    ubyte[8] crc64; /* CRC64-ISO */
    @autoEndian uint32_t count; /* 4 bytes */
    @autoEndian uint16_t payloadVersion; /* 2 bytes  */
    PayloadType type; /* 1 byte  */
    PayloadCompression compression; /* 1 byte */
}

static assert(Payload.sizeof == 32,
        "Payload size must be 16 bytes, not " ~ Payload.sizeof.stringof ~ " bytes");
