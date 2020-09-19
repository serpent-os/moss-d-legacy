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

module moss.format.binary.layout;

public import std.stdint;

enum FileType : uint8_t
{
    /* Catch errors */
    Unknown = 0,

    /** Regular file **/
    Regular = 1,

    /** Symbolic link to another location */
    Symlink = 2,

    /** Directory */
    Directory = 3,

    /** Character Device */
    CharacterDevice = 4,

    /** Block device */
    BlockDevice = 5,

    /** Fifo pipe */
    Fifo = 6,

    /** Socket */
    Socket = 7,
}

/**
 * A LayoutEntry is a multipart key that defines the origin of
 * a constructed path.
 *
 * The corresponding value of the key will contain two values,
 * the origin, and the target. In all regular file cases, the
 * origin will be a hash ID so that files may be linked out from
 * the system hash store.
 *
 * In the instance of directories, the origin will be blank and skipped.
 * In the case of symlinks, the origin will be the source of the symlink.
 * And finally, for special files (mkdev) the origin will be the uint32_t
 * device number encoded as a uint32_t.
 *
 * The tag field is reserved for internal use, allowing individual paths
 * to be flagged as a certain *kind* of file, which may in turn trigger
 * some kind of action.
 */
extern (C) struct LayoutEntry
{
align(1):

    uint64_t time; /* 8 bytes */

    uint32_t uid; /* 4 bytes */
    uint32_t gid; /* 4 bytes */
    uint32_t mode; /* 4 bytes */
    uint32_t tag; /* 4 bytes */

    uint16_t sourceLength; /* 2 bytes */
    uint16_t targetLength; /* 2 bytes */

    FileType type; /* 1 byte */

    ubyte[3] padding;

    /**
     * Encode the Header to the underlying file stream
     */
    final void encode(ref ubyte[] p) @trusted nothrow
    {

        p ~= (cast(ubyte*)&time)[0 .. time.sizeof];
        p ~= (cast(ubyte*)&uid)[0 .. uid.sizeof];
        p ~= (cast(ubyte*)&mode)[0 .. mode.sizeof];
        p ~= (cast(ubyte*)&tag)[0 .. tag.sizeof];
        p ~= (cast(ubyte*)&sourceLength)[0 .. sourceLength.sizeof];
        p ~= (cast(ubyte*)&targetLength)[0 .. targetLength.sizeof];
        p ~= (cast(ubyte*)&type)[0 .. type.sizeof];
        p ~= padding;
    }
}

static assert(LayoutEntry.sizeof == 32,
        "LayoutEntry size must be 32 bytes, not " ~ LayoutEntry.sizeof.stringof ~ " bytes");
