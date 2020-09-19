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

module moss.format.binary.layoutPayload;

import moss.format.binary.endianness;
import moss.format.binary.payload;

public import std.stdio : File, FILE;
public import moss.format.binary.layout;

const uint16_t LayoutPayloadVersion = 1;

/**
 * The LayoutPayload contains a series of LayoutEntrys that are then
 * serialised to map a hash ID to a "real" file, i.e. the final filesystem
 * layout.
 */
struct LayoutPayload
{

public:

    Payload pt;
    alias pt this;

    /**
     * Ensure default initialisation is not insane.
     */
    static LayoutPayload opCall()
    {
        LayoutPayload r;
        r.type = PayloadType.Layout;
        r.compression = PayloadCompression.None;
        r.payloadVersion = LayoutPayloadVersion;
        r.length = 0;
        r.size = 0;
        r.numRecords = 0;
        return r;
    }

    final void encode(File file) @trusted
    {
        auto scope fp = file.getFP();
        Payload us = this;
        us.numRecords = 0;

        us.toNetworkOrder();
        us.encode(fp);
    }

    /**
     * Add directory entry
     */
    final void addEntry(ref LayoutEntry entry, string target)
    {
        import std.exception : enforce;

        enforce(entry.type == FileType.Directory, "Unsupported file type for directory variant");

        addEntryInternal(entry, null, target);
    }

    /**
     * Add typical string entry (symlink, file)
     */
    final void addEntry(ref LayoutEntry entry, string source, string target)
    {
        import std.exception : enforce;

        addEntryInternal(entry, cast(ubyte[]) source, target);
    }

    /**
     * Add special device entry
     */
    final void addEntry(ref LayoutEntry entry, uint32_t source, string target)
    {
        import std.exception : enforce;
        import std.bitmanip;

        ubyte[4] bytes = 0;
        enforce(entry.type >= FileType.CharacterDevice
                && entry.type <= FileType.Socket, "Unsupported file type for uint32_t source");
        version (LittleEndian)
        {
            bytes = nativeToBigEndian(source);
        }
        else
        {
            bytes = cast(ubyte[]) source;
        }
        addEntryInternal(entry, bytes, target);
    }

private:

    /**
     * Handle encoding datum
     */
    final void addEntryInternal(ref LayoutEntry entry, ubyte[] source, string target)
    {

    }

    ubyte[] binary;
}
