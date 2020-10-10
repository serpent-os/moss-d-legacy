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
import moss.format.source.tuningFlag;
import moss.format.source.tuningGroup;

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
    TuningFlag[string] flags;
    TuningGroup[string] groups;

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

        scope (exit)
        {
            _file.close();
        }

        auto loader = Loader.fromFile(_file);
        try
        {
            auto root = loader.load();
            parseMacros("actions", actions, root);
            parseMacros("definitions", definitions, root);
            parseFlags(root);
            parseTuning(root);
        }
        catch (Exception ex)
        {
            import std.stdio;

            stderr.writefln("Failed to parse: %s", _file.name);
            throw ex;
        }
    }

private:

    /**
     * Parse all Flag types.
     */
    final void parseFlags(ref Node root)
    {
        import std.exception : enforce;

        if (!root.containsKey("flags"))
        {
            return;
        }

        /* Grab root sequence */
        Node node = root["flags"];
        enforce(node.nodeID == NodeID.sequence, "parseFlags(): Expected sequence for flags");

        foreach (ref Node k; node)
        {
            assert(k.nodeID == NodeID.mapping, "Each item in flags must be a mapping");
            foreach (ref Node c, ref Node v; k)
            {
                enforce(v.nodeID == NodeID.mapping, "parseFlags: Expected map for each item");
                TuningFlag tf;
                auto name = c.as!string;
                parseSection(v, tf);
                parseSection(v, tf.root);

                /* Handle GNU key */
                if (v.containsKey("gnu"))
                {
                    Node gnu = v["gnu"];
                    enforce(gnu.nodeID == NodeID.mapping,
                            "parseFlags(): expected gnu section to be a mapping");
                    parseSection(gnu, tf.gnu);
                }

                /* Handle LLVM key */
                if (v.containsKey("llvm"))
                {
                    Node llvm = v["llvm"];
                    enforce(llvm.nodeID == NodeID.mapping,
                            "parseFlags(): expected llvm section to be a mapping");
                    parseSection(llvm, tf.llvm);
                }

                /* Store flags now */
                flags[name] = tf;
            }
        }
    }

    final void parseTuning(ref Node root)
    {
        import std.exception : enforce;

        if (!root.containsKey("tuning"))
        {
            return;
        }

        import std.stdio;

        /* Grab root sequence */
        Node node = root["tuning"];
        enforce(node.nodeID == NodeID.sequence, "parseTuning(): Expected sequence for tuning");

        foreach (ref Node k; node)
        {
            assert(k.nodeID == NodeID.mapping, "Each item in tuning must be a mapping");
            foreach (ref Node c, ref Node v; k)
            {
                enforce(v.nodeID == NodeID.mapping, "parseTuning: Expected map for each item");
                TuningGroup group;
                auto name = c.as!string;
                parseSection(v, group);
                parseSection(v, group.root);

                /* Handle all options */
                if (v.containsKey("options"))
                {
                    auto options = v["options"];
                    enforce(options.nodeID == NodeID.sequence,
                            "parseTuning(): Expected sequence for options");

                    /* Grab each option key now */
                    foreach (ref Node kk; options)
                    {
                        assert(kk.nodeID == NodeID.mapping,
                                "Each item in tuning options must be a mapping");
                        foreach (ref Node cc, ref Node vv; kk)
                        {
                            TuningOption to;

                            /* Disallow duplicates */
                            auto childName = cc.as!string;
                            enforce(!(childName in group.choices),
                                    "parseTuning: Duplicate option found in " ~ name);

                            /* Parse the option and store it */
                            parseSection(vv, to);
                            group.choices[childName] = to;
                        }
                    }
                }

                /* If we have options, a default MUST be set */
                if (group.choices !is null && group.choices.length > 0)
                {
                    enforce(group.defaultChoice !is null,
                            "parseTuning: default value missing for option set " ~ name);
                }
                else if (group.choices is null || group.choices.length < 1)
                {
                    enforce(group.defaultChoice is null,
                            "parseTuning: default value unsupported for option set " ~ name);
                }
                groups[name] = group;
            }
        }
    }

    final void parseMacros(string name, ref string[string] target, ref Node root)
    {
        import std.exception : enforce;
        import std.string;

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
