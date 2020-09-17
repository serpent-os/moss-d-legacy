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

module moss.format.binary.reader;

public import std.stdio : File;
import moss.format.binary.endianness;
import moss.format.binary.header;
import moss.format.binary.record;

/**
 * Current entry type in the archive
 */
enum EntryType
{
    Header = 0,
    Record = 1,
    Payload = 2,
}

/**
 * Current Entry in the arhive
 */
struct Entry
{
    union
    {
        Record record;
        Header header;
    };
    EntryType type;
}

/**
 * The Reader is a low-level mechanism for parsing Moss binary packages.
 */
struct Reader
{

private:

    File _file;
    Header _header;
    uint16_t recordIndex;
    Entry curEntry;

    /**
     * Return the next record in the Reader.
     */
    Record nextRecord() @trusted
    {
        import std.exception : enforce;
        import std.stdio : fread, fseek, SEEK_CUR;

        if (!hasNextRecord)
        {
            auto ret = Record();
            ret.type = RecordType.Unknown;
            ret.tag = RecordTag.Unknown;
            return ret;
        }

        scope auto fp = _file.getFP();

        Record ret;
        enforce(fread(&ret, Record.sizeof, 1, fp) == 1, "nextRecord(): Failed to read");
        ret.toHostOrder();

        /* TODO: Allow reading the value - skip for now */
        _file.seek(ret.length, SEEK_CUR);
        ++recordIndex;

        return ret;
    }

public:
    @disable this();

    /**
     * Construct a new Reader for the given filename
     */
    this(File file) @trusted
    {
        import std.exception : enforce;
        import std.stdio : fread;

        scope auto fp = file.getFP();

        _file = file;

        auto size = _file.size;
        enforce(size != 0, "Reader(): empty file");
        enforce(size > Header.sizeof, "Reader(): File too small");
        enforce(fread(&_header, Header.sizeof, 1, fp) == 1, "Reader(): Failed to read Header");

        _header.toHostOrder();
        _header.validate();

        curEntry.type = EntryType.Header;
        curEntry.header = _header;
    }

    ~this() @safe
    {
        close();
    }

    /**
     * Return true while the Reader still has more records available
     */
    pragma(inline, true) pure @property final bool hasNextRecord() @safe @nogc nothrow
    {
        return recordIndex < _header.numRecords;
    }

    /**
     * Return the current entry in the reader
     */
    final @property Entry front()
    {
        return curEntry;
    }

    /**
     * Return true if there are no more entries
     */
    final pure @property bool empty()
    {
        return !(recordIndex < _header.numRecords);
    }

    /**
     * Pop the current entry and find the next
     */
    final @property Entry popFront()
    {
        curEntry.type = EntryType.Record;
        curEntry.record = nextRecord();
        return curEntry;
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
        _file.close();
    }
}
