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

module moss.format.binary.writer;

public import std.stdio : File;

import moss.format.binary : MossFormatVersionNumber;
import moss.format.binary.endianness;
import moss.format.binary.header;
import moss.format.binary.record;

/**
 * The Writer is a low-level mechanism for writing Moss binary packages
 */
struct Writer
{

private:

    File _file;
    Header _header;

public:
    @disable this();

    /**
     * Construct a new Writer for the given filename
     */
    this(File file, uint32_t versionNumber = MossFormatVersionNumber) @trusted
    {
        _file = file;
        scope auto fp = _file.getFP();
        _header = Header(versionNumber);
        _header.numRecords = 0;
        _header.toNetworkOrder();
        _header.encode(fp);
        _header.toHostOrder();
    }

    /**
     * Return the filetype for this Writer
     */
    pure final @property MossFileType fileType() @safe @nogc nothrow
    {
        return _header.type;
    }

    /**
     * Set the filetype for this Writer
     */
    final @property void fileType(MossFileType type) @safe @nogc nothrow
    {
        _header.type = type;
    }

    ~this() @safe
    {
        close();
    }

    /**
     * Flush and close the underying file.
     */
    final void close() @safe
    {
        if (!_file.isOpen())
        {
            return;
        }
        _file.seek(0);
        scope auto fp = _file.getFP();
        _header.toNetworkOrder();
        _header.encode(fp);
        _file.flush();
        _header.toHostOrder();
        _file.close();
    }

    /**
     * Attempt to add a record to the stream. The type of T must be the
     * type expected in the key type
     */
    final void addRecord(R : RecordTag, T)(R key, T datum) @trusted
    {
        import std.traits;
        import std.conv : to;
        import std.stdio;

        scope auto fp = _file.getFP();

        Record record;
        void delegate() encoder;

        void encodeString()
        {
            static if (is(T == string))
            {
                import std.stdio : fwrite;
                import std.exception : enforce;
                import std.string : toStringz;

                auto z = toStringz(datum);
                assert(datum.length < uint32_t.max, "addRecord(): String Length too long");
                record.length = cast(uint32_t) datum.length + 1;

                enforce(fwrite(z, z[0].sizeof, record.length,
                        fp) == record.length, "encodeString(): Failed to write");
            }
        }

        void encodeNumeric()
        {
            static if (!is(T == string))
            {
                import std.bitmanip;
                import std.stdio : fwrite;
                import std.exception : enforce;

                record.length = cast(uint32_t) T.sizeof;

                /* Ensure we encode big-endian values only */
                version (BigEndian)
                {
                    enforce(fwrite(&datum, T.sizeof, 1, fp) == 1,
                            "encodeNumeric(): Failed to write");
                }
                else
                {
                    static if (T.sizeof > 1)
                    {
                        ubyte[T.sizeof] b = nativeToBigEndian(datum);
                        enforce(fwrite(b.ptr, b[0].sizeof, T.sizeof,
                                fp) == T.sizeof, "encodeNumeric(): Failed to write");

                    }
                    else
                    {
                        enforce(fwrite(&datum, T.sizeof, 1, fp) == 1,
                                "encodeNumeric(): Failed to write");
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
                    assert(typeid(datum) == typeid(string),
                            "addRecord(RecordTag." ~ memberName ~ ") expects string, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.String;
                    encoder = &encodeString;
                    break;

                case RecordType.Int8:
                    assert(typeid(datum) == typeid(int8_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects int8_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Int8;
                    encoder = &encodeNumeric;
                    break;
                case RecordType.Uint8:
                    assert(typeid(datum) == typeid(uint8_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects uint8_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Uint8;
                    encoder = &encodeNumeric;
                    break;

                case RecordType.Int16:
                    assert(typeid(datum) == typeid(int16_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects int16_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Int16;
                    encoder = &encodeNumeric;
                    break;
                case RecordType.Uint16:
                    assert(typeid(datum) == typeid(uint16_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects uint16_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Uint16;
                    encoder = &encodeNumeric;
                    break;
                case RecordType.Int32:
                    assert(typeid(datum) == typeid(int32_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects int32_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Int32;
                    encoder = &encodeNumeric;
                    break;
                case RecordType.Uint32:
                    assert(typeid(datum) == typeid(uint32_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects uint32_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Uint32;
                    encoder = &encodeNumeric;
                    break;
                case RecordType.Int64:
                    assert(typeid(datum) == typeid(int64_t),
                            "addRecord(RecordTag." ~ memberName ~ ") expects int64_t, not " ~ typeof(datum)
                            .stringof);
                    writeln("Writing key: ", key, " - value: ", datum);
                    record.type = RecordType.Int64;
                    encoder = &encodeNumeric;
                    break;
                case RecordType.Uint64:
                    assert(typeid(datum) == typeid(uint64_t),
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
        record.toNetworkOrder();
        record.encode(fp);

        _header.numRecords++;

        assert(encoder !is null, "Missing encoder");
        encoder();
    }
}
