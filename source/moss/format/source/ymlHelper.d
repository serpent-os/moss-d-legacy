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

module moss.format.source.ymlHelper;

import dyaml;
import moss.format.source.schema;
import std.stdint;

/**
 * Set value appropriately.
 */
final void setValue(T)(ref Node node, ref T value, YamlSchema schema)
{
    import std.exception : enforce;
    import std.algorithm : canFind;
    import std.string : format;

    enforce(node.nodeID == NodeID.scalar, "Expected " ~ T.stringof ~ " for " ~ node.tag);

    static if (is(T == int64_t))
    {
        value = node.as!int64_t;
    }
    else static if (is(T == uint64_t))
    {
        value = node.as!uint64_t;
    }
    else static if (is(T == bool))
    {
        value = node.as!bool;
    }
    else
    {
        value = node.as!string;
        if (schema.acceptableValues.length < 1)
        {
            return;
        }

        /* Make sure the string is an acceptable value */
        enforce(schema.acceptableValues.canFind(value),
                "setValue(): %s not a valid value for %s. Acceptable values: %s".format(value,
                    schema.name, schema.acceptableValues));
    }
}

/**
 * Set value according to maps.
 */
final void setValueArray(T)(ref Node node, ref T value)
{
    import std.exception : enforce;

    /* We can support a single value *or* a list. */
    enforce(node.nodeID != NodeID.mapping, "Expected " ~ T.stringof ~ " for " ~ node.tag);

    switch (node.nodeID)
    {
    case NodeID.scalar:
        value ~= node.as!(typeof(value[0]));
        break;
    case NodeID.sequence:
        foreach (ref Node v; node)
        {
            value ~= v.as!(typeof(value[0]));
        }
        break;
    default:
        break;
    }
}

final void parseSection(T)(ref Node node, ref T section) @system
{
    import std.traits;
    import std.exception : enforce;

    /* Walk members */
    static foreach (member; __traits(allMembers, T))
    {
        {
            mixin("import " ~ moduleName!T ~ ";");

            mixin("enum udaID = getUDAs!(" ~ T.stringof ~ "." ~ member ~ ", YamlSchema);");
            static if (udaID.length == 1)
            {
                static assert(udaID.length == 1, "Missing YamlSchema for " ~ T.stringof
                        ~ "." ~ member);
                enum yamlName = udaID[0].name;
                enum mandatory = udaID[0].required;
                enum type = udaID[0].type;

                static if (mandatory)
                {
                    enforce(node.containsKey(yamlName), "Missing mandatory key: " ~ yamlName);
                }

                static if (type == YamlType.Single)
                {
                    if (node.containsKey(yamlName))
                    {
                        auto yamlNode = node[yamlName];
                        mixin("setValue(yamlNode, section." ~ member ~ ", udaID);");
                    }
                }
                else static if (type == YamlType.Array)
                {
                    if (node.containsKey(yamlName))
                    {
                        auto yamlNode = node[yamlName];
                        mixin("setValueArray(yamlNode, section." ~ member ~ ");");
                    }
                }
            }
        }
    }
}
