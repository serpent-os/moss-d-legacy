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

module moss.format.binary.header;

import std.stdint;
import moss.format.binary.endianness;

/**
 * Standard file header: NUL M O S
 */
const uint32_t MossFileHeader = 0x006d6f73;

/**
 * Hard-coded integrity check built into the first 32-byte header.
 * It never changes, it is just there to trivially detect early
 * corruption.
 */
const ubyte[21] IntegrityCheck = [
    0, 0, 1, 0, 0, 2, 0, 0, 3, 0, 0, 4, 0, 0, 5, 0, 0, 6, 0, 0, 7
];

/**
 * Type of package expected for moss
 */
enum MossFileType : uint8_t
{
    Unknown = 0,
    Binary,
    Delta,
};

/**
 * The header struct simply verifies the file as a valid moss package file.
 * It additionally contains the number of records within the file, the
 * format version, and the type of package (currently delta or binary).
 * For super paranoid reasons we also include a fixed integrity check
 * to ensure no corruption in the file lead.
 *
 * All other information is contained within the subsequent records
 * and tagged with the relevant information, ensuring the format doesn't
 * become too restrictive.
 */
struct Header
{
public:

    @autoEndian uint32_t magic; /* 4 bytes */
    @autoEndian uint16_t numRecords; /* 2 bytes */
    ubyte[21] padding;
    MossFileType type; /* 1-byte */
    @autoEndian uint32_t versionNumber; /* 4 bytes */

    this(uint32_t versionNumber)
    {
        this.magic = MossFileHeader;
        this.numRecords = 0;
        this.padding = IntegrityCheck;
        this.type = MossFileType.Binary;
        this.versionNumber = versionNumber;
    }
};

/**
 * Make sure we don't introduce alignment bugs and kill the header
 * size.
 */
static assert(Header.sizeof == 32,
        "Header must be 32-bytes only, found " ~ Header.sizeof.stringof ~ " bytes");
