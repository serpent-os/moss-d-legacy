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

module moss.build.stage;

import moss.build.profile : BuildProfile;

/**
 * An ExecutionStage is a single step within the build process.
 * It contains the execution script required to run as well as the name,
 * working directory, etc.
 */
struct ExecutionStage
{

public:

    @disable this();

    /**
     * Construct a new ExecutionStage from the given parent profile
     */
    this(BuildProfile* parent, string name)
    {
        _parent = parent;
        _name = name;
        _script = null;
    }

    /**
     * Return the name for this stage
     */
    pure final @property string name() @safe @nogc nothrow
    {
        return _name;
    }

    /**
     * Return the parent build profile
     */
    pure final @property BuildProfile* parent() @safe @nogc nothrow
    {
        return _parent;
    }

    /**
     * Return the underlying script.
     */
    pure final @property string script() @safe @nogc nothrow
    {
        return _script;
    }

    /**
     * Set the script to a new string
     */
    final @property void script(in string sc) @safe
    {
        _script = _parent.script.process(sc);
    }

private:

    BuildProfile* _parent = null;
    string _name = null;
    string _script = null;
}
