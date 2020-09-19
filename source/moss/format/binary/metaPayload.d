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

module moss.format.binary.metaPayload;

import moss.format.binary.endianness;
import moss.format.binary.payload;
import moss.format.binary.record;

/**
 * The MetaPayload type allows us to encode metadata into a payload
 * trivially.
 */
struct MetaPayload
{

public:

    Payload pt;
    alias pt this;

    /**
     * Ensure default initialisation is not insane.
     */
    static MetaPayload opCall()
    {
        MetaPayload r;
        r.type = PayloadType.Meta;
        r.compression = PayloadCompression.None;
        return r;
    }

    /**
     * Add Records with their associated data.
     */
    final void addRecord(R : RecordTag, T)(R key, auto const ref T datum) @trusted
    {
        import std.traits;
        import std.conv : to;
        import std.stdio;

        Record record;
        void delegate() encoder;

        void encodeString()
        {
            static if (is(T == string))
            {
                import std.stdio : fwrite;
                import std.exception : enforce;
                import std.string : toStringz;

                /* Stash length before writing record to file */
                auto z = toStringz(datum);
                assert(datum.length < uint32_t.max, "addRecord(): String Length too long");
                record.length = cast(uint32_t) datum.length + 1;
                auto len = record.length;

                /* Write record to file */
                record.toNetworkOrder();
                record.encode(binary);

                binary ~= (cast(ubyte*) z)[0 .. len];
            }
        }

        void encodeNumeric()
        {
            static if (!is(T == string))
            {
                import std.bitmanip;
                import std.stdio : fwrite;
                import std.exception : enforce;

                /* Stash length before writing record to file */
                record.length = cast(uint32_t) T.sizeof;

                /* Write record to file */
                record.toNetworkOrder();
                record.encode(binary);

                /* Ensure we encode big-endian values only */
                version (BigEndian)
                {
                    binary ~= (cast(ubyte*)&datum)[0 .. T.sizeof];
                }
                else
                {
                    static if (T.sizeof > 1)
                    {
                        ubyte[T.sizeof] b = nativeToBigEndian(datum);
                        binary ~= b;
                    }
                    else
                    {
                        binary ~= (cast(ubyte*)&T)[0 .. T.sizeof];
                    }
                }
            }
        }

        static foreach (i, m; EnumMembers!RecordTag)
        {
            if (i == key)
            {
                mixin("enum memberName = __traits(identifier, EnumMembers!RecordTag[i]);");
                mixin("enum attrs = __traits(getAttributes, RecordTag." ~ to!string(
                        memberName) ~ ");");
                static assert(attrs.length == 1,
                        "Missing validation tag for RecordTag." ~ to!string(memberName));

                switch (attrs[0])
                {

                    /* Handle string */
                case RecordType.String:
                    assert(typeid(OriginalType!T) == typeid(string),
                            "addRecord(RecordTag." ~ memberName ~ ") expects string, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.String;
                    encoder = &encodeString;
                    break;

                case RecordType.Int8:
                    assert(typeid(OriginalType!T) == typeid(int8_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects int8_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Int8;
                    encoder = &encodeNumeric;
                    break;
                case RecordType.Uint8:
                    assert(typeid(OriginalType!T) == typeid(uint8_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects uint8_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Uint8;
                    encoder = &encodeNumeric;
                    break;

                case RecordType.Int16:
                    assert(typeid(OriginalType!T) == typeid(int16_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects int16_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Int16;
                    encoder = &encodeNumeric;
                    break;
                case RecordType.Uint16:
                    assert(typeid(OriginalType!T) == typeid(uint16_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects uint16_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Uint16;
                    encoder = &encodeNumeric;
                    break;
                case RecordType.Int32:
                    assert(typeid(OriginalType!T) == typeid(int32_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects int32_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Int32;
                    encoder = &encodeNumeric;
                    break;
                case RecordType.Uint32:
                    assert(typeid(OriginalType!T) == typeid(uint32_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects uint32_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Uint32;
                    encoder = &encodeNumeric;
                    break;
                case RecordType.Int64:
                    assert(typeid(OriginalType!T) == typeid(int64_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects int64_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Int64;
                    encoder = &encodeNumeric;
                    break;
                case RecordType.Uint64:
                    assert(typeid(OriginalType!T) == typeid(uint64_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects uint64_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Uint64;
                    encoder = &encodeNumeric;
                    break;
                default:
                    assert(0, "INCOMPLETE SUPPORT");
                }
            }
        }

        record.tag = key;
        numRecords++;

        assert(encoder !is null, "Missing encoder");
        encoder();
    }

    /**
     * Encode our data to the archive
     */
    final void encode(scope FILE* fp)
    {
        import std.stdio : fwrite;
        import std.exception : enforce;

        if (numRecords < 0)
        {
            return;
        }

        Payload us = this;
        us.toNetworkOrder();
        us.encode(fp);

        /* Dump our data */
        enforce(fwrite(binary.ptr, binary[0].sizeof, binary.length,
                fp) == binary.length, "MetaPayload.encode(): Failed to write data");
    }

private:

    /* Dynamically allocated storage */
    ubyte[] binary;
}
