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

module moss.build.builder;

import moss.format.source.spec;
import moss.build.context;

/**
 * The Builder is responsible for the full build of a source package
 * and emitting a binary package.
 */
struct Builder
{

public:

    @disable this();

    /**
     * Construct a new Builder with the given input file. It must be
     * a stone.yml formatted file and actually be valid.
     */
    this(string filename)
    {
        auto f = File(filename, "r");
        specFile = Spec(f);
        specFile.parse();

        /* TODO: UNHACK ME */
        addArchitecture("x86_64");
        addArchitecture("ia32");
    }

    /**
     * Return the underlying spec file
     */
    pure final @property ref Spec specFile()
    {
        return _specFile;
    }

    /**
     * Add an architecture to the build list
     */
    final void addArchitecture(string name)
    {
        architectures ~= name;
    }

    /**
     * Full build cycle
     */
    final void build()
    {
        /**
         * Construct new build context for each architecture that is
         * enabled, and in future, build with it.
         */
        foreach (ref a; architectures)
        {
            auto context = BuildContext(&_specFile, a);
            import std.stdio;

            writeln(context);
        }
    }

private:

    /**
     * Update the underlying spec file
     */
    final @property void specFile(ref Spec s)
    {
        _specFile = s;
    }

    Spec _specFile;
    string[] architectures;
}
