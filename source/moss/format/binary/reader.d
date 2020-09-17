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
 * The Reader is a low-level mechanism for parsing Moss binary packages.
 */
struct Reader
{

private:

    File _file;
    Header _header;

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

        /* Demo code */
        import std.stdio;
        import std.conv : to;

        writeln(_header);
        writeln("Found " ~ to!string(_header.numRecords) ~ " records in the file");

        foreach (recordIndex; 0 .. _header.numRecords)
        {
            Record record;
            fread(&record, Record.sizeof, 1, fp);
            record.toHostOrder();
            writeln(record);

            if (record.type == RecordType.String)
            {
                writeln("\t ", cast(string)(_file.rawRead(new ubyte[record.length])));
            }
            else
            {
                /* Skip the value */
                _file.seek(record.length, SEEK_CUR);
            }
        }
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
        _file.close();
    }
}
