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

module moss.util;

import core.sys.posix.unistd;
import core.stdc.string;
import core.stdc.errno;
import std.exception : enforce;
import std.string : format, toStringz;

/**
 * Attempt construction of a hardlink.
 */
pragma(inline, true) void hardLink(const(string) sourcePath, const(string) destPath) @trusted
{
    auto sourceZ = sourcePath.toStringz;
    auto targetZ = destPath.toStringz;

    auto ret = link(sourceZ, targetZ);
    enforce(ret == 0, "hardLink(): Failed to link %s to %s: %s".format(sourcePath,
            destPath, strerror(errno)));
}

/**
 * Attempt hardlink, if it fails, fallback to a copy
 */
pragma(inline, true) void hardLinkOrCopy(const(string) sourcePath, const(string) destPath) @trusted
{
    try
    {
        hardLink(sourcePath, destPath);
        return;
    }
    catch (Exception ex)
    {
    }

    import std.file : copy;

    copy(sourcePath, destPath);
}

/**
 * Returns true if the path exists and is writable
 */
pragma(inline, true) bool checkWritable(const(string) path) @trusted
{
    return access(path.toStringz, W_OK) == 0;
}
