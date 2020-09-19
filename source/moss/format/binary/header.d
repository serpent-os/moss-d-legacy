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

public import std.stdint;
public import std.stdio : FILE;
import moss.format.binary.endianness;
import moss.format.binary : MossFormatVersionNumber;

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
extern (C) struct Header
{
align(1):
    @autoEndian uint32_t magic; /* 4 bytes */
    @autoEndian uint16_t numPayloads; /* 2 bytes */
    ubyte[21] padding;
    MossFileType type; /* 1-byte */
    @autoEndian uint32_t versionNumber; /* 4 bytes */

    this(uint32_t versionNumber) @safe @nogc nothrow
    {
        this.magic = MossFileHeader;
        this.numPayloads = 0;
        this.padding = IntegrityCheck;
        this.type = MossFileType.Binary;
        this.versionNumber = versionNumber;
    }

    /**
     * Encode the Header to the underlying file stream
     */
    final void encode(scope FILE* fp) @trusted
    {
        import std.stdio : fwrite;
        import std.exception : enforce;

        enforce(fwrite(&magic, magic.sizeof, 1, fp) == 1, "Failed to write Header.magic");
        enforce(fwrite(&numPayloads, numPayloads.sizeof, 1, fp) == 1,
                "Failed to write Header.numPayloads");
        enforce(fwrite(padding.ptr, padding[0].sizeof, padding.length,
                fp) == padding.length, "Failed to write Header.padding");
        enforce(fwrite(&type, type.sizeof, 1, fp) == 1, "Failed to write Header.type");
        enforce(fwrite(&versionNumber, versionNumber.sizeof, 1, fp) == 1,
                "Failed to write Header.sizeof");
    }

    /**
     * Ensure that a header is actually valid before proceeding
     */
    final void validate() @safe
    {
        import std.exception : enforce;

        enforce(magic == MossFileHeader, "Header.validate(): invalid magic");
        enforce(padding == IntegrityCheck, "Header.validate(): corrupt integrity");
        enforce(type != MossFileType.Unknown, "Header.validate(): unknown package type");
        enforce(versionNumber <= MossFormatVersionNumber,
                "Header.validate(): unsupported package version");
    }
};

/**
 * Make sure we don't introduce alignment bugs and kill the header
 * size.
 */
static assert(Header.sizeof == 32,
        "Header must be 32-bytes only, found " ~ Header.sizeof.stringof ~ " bytes");
