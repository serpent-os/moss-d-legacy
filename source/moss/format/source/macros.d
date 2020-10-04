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

module moss.format.source.macros;

public import std.stdio : File;
import dyaml;
import moss.format.source.ymlHelper;

/**
 * A MacroFile can contain a set of macro definitions, actions and otherwise
 * to form the basis of the ScriptBuilder context. All MacroFiles are loaded
 * at builder initialisation and cached in memory.
 *
 * The root BuilderContext contains all MacroFiles in memory.
 */
struct MacroFile
{

public:

    string[string] actions;
    string[string] definitions;

    /**
     * Construct a Spec from the given file
     */
    this(File _file) @safe
    {
        this._file = _file;
    }

    ~this()
    {
        if (_file.isOpen())
        {
            _file.close();
        }
    }

    /**
     * Attempt to parse the input fiel
     */
    final void parse() @system
    {
        import std.exception : enforce;

        enforce(_file.isOpen(), "MacoFile.parse(): File is not open");

        auto loader = Loader.fromFile(_file);
        try
        {
            auto root = loader.load();
            parseMacros("actions", actions, root);
            parseMacros("definitions", definitions, root);
        }
        catch (Exception ex)
        {
            import std.stdio;

            stderr.writefln("Failed to parse: %s", _file.name);
            throw ex;
        }
    }

private:

    final void parseMacros(string name, ref string[string] target, ref Node root)
    {
        import std.exception : enforce;
        import std.string;

        scope (exit)
        {
            _file.close();
        }

        if (!root.containsKey(name))
        {
            return;
        }

        /* Grab root sequence */
        Node node = root[name];
        enforce(node.nodeID == NodeID.sequence, "parseMacros(): Expected sequence for " ~ name);

        /* Grab each map */
        foreach (ref Node k; node)
        {
            enforce(k.nodeID == NodeID.mapping,
                    "parseMaros(): Expected mapping in sequence for " ~ name);
            import std.stdio;

            auto mappingKeys = k.mappingKeys;
            auto mappingValues = k.mappingValues;

            enforce(mappingKeys.length == 1, "parseMacros(): Expect only ONE key for " ~ name);
            enforce(mappingValues.length == 1, "parseMacros(): Expect only ONE value for " ~ name);

            Node key = mappingKeys[0];
            Node val = mappingValues[0];

            enforce(key.nodeID == NodeID.scalar, "parseMacros: Expected scalar key for " ~ name);
            enforce(val.nodeID == NodeID.scalar, "parseMacros: Expected scalar key for " ~ name);

            auto skey = key.as!string;
            auto sval = val.as!string;

            sval = sval.strip();
            if (sval.endsWith('\n'))
            {
                sval = sval[0 .. $ - 1];
            }
            target[skey] = sval;
        }
    }

    File _file;
};
