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
import moss.format.binary.payload;

/**
 * The Writer is a low-level mechanism for writing Moss binary packages
 */
struct Writer
{

private:

    File _file;
    Header _header;
    Payload*[] payloads;

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
        _header.numPayloads = 0;
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
     * Add the payload to the archive.
     */
    final void addPayload(Payload* payload) @trusted
    {
        payloads ~= payload;
        _header.numPayloads++;
    }

    /**
     * Flush all payloads to disk.
     */
    final void flush() @trusted
    {
        _file.seek(0);

        scope auto fp = _file.getFP();
        _header.toNetworkOrder();
        _header.encode(fp);
        _header.toHostOrder();

        /* Dump all payloads. TODO: Add their records. */
        foreach (ref p; payloads)
        {
            Payload pEnc = *p;
            pEnc.toNetworkOrder();
            pEnc.encode(fp);

            switch (p.type)
            {
            case PayloadType.Meta:
                import moss.format.binary.metaPayload;

                auto m = cast(MetaPayload*) p;
                m.encode(fp);
                break;
            default:
                assert(0, "Unsupported type: " ~ p.type.stringof);
            }
        }

        _file.flush();
    }
}
