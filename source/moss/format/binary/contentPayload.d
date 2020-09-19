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

module moss.format.binary.contentPayload;

import moss.format.binary.endianness;
import moss.format.binary.payload;

const uint16_t ContentPayloadVersion = 1;

/**
 * The ContentPayload contains concatenated data that may or may not
 * be compressed. It is one very large blob, and does not much else.
 */
struct ContentPayload
{

public:

    Payload pt;
    alias pt this;

    /**
     * Ensure default initialisation is not insane.
     */
    static ContentPayload opCall()
    {
        ContentPayload r;
        r.type = PayloadType.Content;
        r.compression = PayloadCompression.None;
        r.payloadVersion = ContentPayloadVersion;
        r.length = 0;
        r.size = 0;
        r.numRecords = 0;
        return r;
    }

    /**
     * Encode our data to the archive
     */
    final void encode(scope FILE* fp)
    {
        import std.stdio : fwrite;
        import std.exception : enforce;

        Payload us = this;

        us.toNetworkOrder();
        us.encode(fp);

        import std.stdio;

        /* Now read and copy each file into the archive */
        foreach (k; order)
        {
            auto v = content[k];
            writeln(k, " = ", v);
        }
    }

    /**
     * Add a file to the content payload. It will not be loaded or
     * written until the archive is being flushed.
     */
    final void addFile(string hashID, string sourcePath)
    {
        assert(!(hashID in content), "addFile(): must be a unique hash");
        content[hashID] = sourcePath;
        order ~= hashID;
        numRecords++;
    }

private:

    string[string] content;
    string[] order;
}
