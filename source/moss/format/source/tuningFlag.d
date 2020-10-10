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

module moss.format.source.tuningFlag;

public import moss.format.source.schema;

final struct CompilerFlags
{
    @YamlSchema("c") string cflags = null;
    @YamlSchema("cxx") string cxxflags = null;
    @YamlSchema("ld") string ldflags = null;
}

/**
 * Access pattern: Do you want LLVM or GNU?
 */
final enum Toolchain
{
    LLVM = 0,
    GNU = 1,
};

/**
 * A TuningFlag encapsulates common flags used for a given purpose,
 * such as optimising for speed, etc.
 *
 * Our type adds dependencies + accessors to abstract
 * GNU vs LLVM differences
 */
final struct TuningFlag
{
    /**
     * GNU specific options
     */
    CompilerFlags gnu;

    /**
     * LLVM specific options
     */
    CompilerFlags llvm;

    /**
     * Root level flags
     */
    CompilerFlags root;

    /**
     * Return the CFLAGS
     */
    pure final @property string cflags(Toolchain toolchain) @safe @nogc nothrow
    {
        if (toolchain == Toolchain.GNU && gnu.cflags != null)
        {
            return gnu.cflags;
        }
        else if (toolchain == Toolchain.LLVM && llvm.cflags != null)
        {
            return llvm.cflags;
        }
        return root.cflags;
    }

    /**
     * Return the CXXFLAGS
     */
    pure final @property string cxxflags(Toolchain toolchain) @safe @nogc nothrow
    {
        if (toolchain == Toolchain.GNU && gnu.cxxflags != null)
        {
            return gnu.cxxflags;
        }
        else if (toolchain == Toolchain.LLVM && llvm.cxxflags != null)
        {
            return llvm.cxxflags;
        }
        return root.cxxflags;
    }

    /**
     * Return the LDFLAGS
     */
    pure final @property string ldflags(Toolchain toolchain) @safe @nogc nothrow
    {
        if (toolchain == Toolchain.GNU && gnu.ldflags != null)
        {
            return gnu.ldflags;
        }
        else if (toolchain == Toolchain.LLVM && llvm.ldflags != null)
        {
            return llvm.ldflags;
        }
        return root.ldflags;
    }

}
