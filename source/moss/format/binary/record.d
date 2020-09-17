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

module moss.format.binary.record;

public import std.stdint;
import moss.format.binary.endianness;

/**
 * The type of record encountered.
 * We limit this to a small selection of predefined data types.
 */
enum RecordType : uint8_t
{
    Unknown = 0,
    Int8 = 1,
    Uint8 = 2,
    Int16 = 3,
    Uint16 = 4,
    Int32 = 5,
    Uint32 = 6,
    Int64 = 7,
    Uint64 = 8,
    Binary = 9,
    String = 10,
}

/**
 * We support a predefined set of record types which are additionally
 * tagged for their type.
 */
enum RecordTag : uint16_t
{
    @(RecordType.Unknown) Unknown = 0,

    /** Name of the package */
    @(RecordType.String) Name = 1,

    /** Architecture of the package */
    @(RecordType.String) Architecture = 2,

    /** Version of the package */
    @(RecordType.String) Version = 3,

    /** Summary of the package */
    @(RecordType.String) Summary = 4,

    /** Description of the package */
    @(RecordType.String) Description = 5,

    /** Homepage for the package */
    @(RecordType.String) Homepage = 6,

    /** ID for the source package, used for grouping */
    @(RecordType.String) SourceID = 7,

    /** Runtime dependencies */
    @(RecordType.Unknown) Depends = 8,

    /** Provides some capability or name */
    @(RecordType.Unknown) Provides = 9,

    /** Conflicts with some capability or name */
    @(RecordType.Unknown) Conflicts = 10,

    /** Release number for the package */
    @(RecordType.Int64) Release = 11,

    /** SPDX license identifier */
    @(RecordType.String) License = 12,
}

/**
 * Records are found in each moss package after the initial header.
 * They contain all meta-information on the package and are variable
 * length in nature.
 *
 * To skip all records requires skipping the length of every record
 * encountered. The payload will then be encountered before the final 0
 * byte.
 */
struct Record
{
align(1):
    @autoEndian uint32_t length; /** 4 bytes per record length*/
    @autoEndian RecordTag tag; /** 2 bytes for the tag */
    RecordType type; /** 1 byte for the type */
    ubyte[1] padding;
};

static assert(Record.sizeof == 8,
        "Record size must be 8 bytes, not " ~ Record.sizeof.stringof ~ " bytes");
