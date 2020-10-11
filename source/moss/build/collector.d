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

module moss.build.collector;

/**
 * The BuildCollector is responsible for collecting and analysing the
 * contents of the build root, and assigning packages for each given
 * path.
 *
 * By default, all files will end up in the main package unless explicitly
 * overridden by a pattern.
 */
final struct BuildCollector
{

public:

    /**
     * Begin collection on the given root directory, considered to be
     * the "/" root filesystem of the target package.
     */
    final void collect(const(string) rootDir) @safe
    {
        import std.stdio;

        writefln("Collecting from: %s", rootDir);
    }
}
