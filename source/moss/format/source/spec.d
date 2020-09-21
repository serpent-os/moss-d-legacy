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

module moss.format.source.spec;

public import std.stdint;
public import std.stdio : File;
public import moss.format.source.schema;

import dyaml;

/**
 * A Build Definition provides the relevant steps to complete production
 * of a package. All steps are optional.
 */
struct BuildDefinition
{
    /**
     * Setup step.
     *
     * These instructions should perform any required setup work such
     * as patching, configuration, etc.
     */
    @YamlSchema("setup") string stepSetup;

    /**
     * Build step.
     *
     * These instructions should begin compilation of the source, such
     * as with "make".
     */
    @YamlSchema("build") string stepBuild;

    /**
     * Install step.
     *
     * This is the final step, and should be used to install the
     * files produced by the previous steps into the target "collection"
     * area, ready to be converted into a package.
     */
    @YamlSchema("install") string stepInstall;

    /**
     * Build dependencies
     *
     * We list build dependencies in a format suitable for consumption
     * by the package manager.
     */
    @YamlSchema("builddeps", false, YamlType.Array) string[] buildDependencies;
};

/**
 * A Package Definition allows overriding of specific values from the
 * root context for a sub package.
 */
struct PackageDefinition
{

    /**
     * A brief summary of the what the package is.
     */
    @YamlSchema("summary") string summary;

    /**
     * A longer description of the package, i.e. its aims, use cases,
     * etc.
     */
    @YamlSchema("description") string description;

    /**
     * A list of other "things" (symbols, names) to depend on for
     * installation to be functionally complete.
     */
    @YamlSchema("rundeps", false, YamlType.Array) string[] runtimeDependencies;

    /**
     * A series of paths that should be included within this subpackage
     * instead of being collected into automatic subpackages or the
     * main package. This overrides automatic collection and allows
     * custom subpackages to be created.
     */
    @YamlSchema("paths", false, YamlType.Array) string[] paths;
};

/**
 * Source definition details the root name, version, etc, and where
 * to get sources
 */
struct SourceDefinition
{
    /**
     * The base name of the software package. This should follow both
     * the upstream name and the packaging policies.
     */
    @YamlSchema("name", true) string name;

    /**
     * A version identifier for this particular release of the software.
     * This has no bearing on selections, and is only provided to allow
     * humans to understand the version of software being included.
     */
    @YamlSchema("version", true) string versionIdentifier;

    /**
     * Releases help determine priority of updates for packages of the
     * same origin. Bumping the release number will ensure an update
     * is performed.
     */
    @YamlSchema("release", true) int64_t release;
};

/**
 * A Spec is a stone specification file. It is used to parse a "stone.yml"
 * formatted file with the relevant meta-data and steps to produce a binary
 * package.
 */
struct Spec
{

public:

    /**
     * Source definition
     */
    SourceDefinition source;

    /**
     * Root context build steps
     */
    BuildDefinition rootBuild;

    /**
     * Profile specific build steps
     */
    BuildDefinition[string] profileBuilds;

    /**
     * Root context package definition
     */
    PackageDefinition rootPackage;

    /**
     * Per package definitions */
    PackageDefinition[string] subPackages;

    /**
     * Construct a Spec from the given file
     */
    this(File _file) @safe
    {
        this._file = _file;
    }

    /**
     * Attempt to parse the input fiel
     */
    final void parse() @system
    {
        import std.exception : enforce;

        enforce(_file.isOpen(), "Spec.parse(): File is not open");

        auto loader = Loader.fromFile(_file);
        auto root = loader.load();

        /* Parse the rootContext source */
        parseSection(root, source);
        parseSection(root, rootBuild);
        parseSection(root, rootPackage);

        parsePackages(root);
        parseBuilds(root);

        import std.stdio;

        writeln(source);
        writeln(rootBuild);
        writeln(rootPackage);

        foreach (k, v; subPackages)
        {
            writeln("Subpackage: " ~ k);
            writeln(v);
        }

        foreach (k, v; profileBuilds)
        {
            writeln("Profile: " ~ k);
            writeln(v);
        }
    }

private:

    /**
     * Find all PackageDefinition instances and set them up
     */
    final void parsePackages(ref Node node)
    {
        import std.exception : enforce;
        import std.stdio;

        if (!node.containsKey("packages"))
        {
            return;
        }

        Node root = node["packages"];
        enforce(root.nodeID == NodeID.sequence,
                "packages key should be a sequence of package definitions");

        /* Step through all items in root */
        foreach (ref Node k; root)
        {
            assert(k.nodeID == NodeID.mapping, "Each item in packages must be a mapping");
            foreach (ref Node c, ref Node v; k)
            {
                PackageDefinition pk;
                auto name = c.as!string;
                parseSection(v, pk);
                subPackages[name] = pk;
            }
        }
    }

    /**
     * Find all BuildDefinition instances and set them up
     */
    final void parseBuilds(ref Node node)
    {
        import std.exception : enforce;
        import std.stdio;

        if (!node.containsKey("profiles"))
        {
            return;
        }

        Node root = node["profiles"];
        enforce(root.nodeID == NodeID.sequence,
                "profiles key should be a sequence of build definitions");

        /* Step through all items in root */
        foreach (ref Node k; root)
        {
            assert(k.nodeID == NodeID.mapping, "Each item in profiles must be a mapping");
            foreach (ref Node c, ref Node v; k)
            {
                BuildDefinition bd;
                auto name = c.as!string;
                parseSection(v, bd);
                profileBuilds[name] = bd;
            }
        }
    }

    /**
     * Set value appropriately.
     */
    final void setValue(T)(ref Node node, ref T value)
    {
        import std.traits;

        static if (is(T == int64_t))
        {
            value = node.as!int64_t;
        }
        else
        {
            value = node.as!string;
        }
    }

    /**
     * Set value according to maps.
     */
    final void setValueArray(T)(ref Node node, ref T value)
    {
        import std.stdio;
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
        import std.stdio;
        import std.exception : enforce;

        /* Walk members */
        static foreach (member; __traits(allMembers, T))
        {
            {
                mixin("enum udaID = getUDAs!(" ~ T.stringof ~ "." ~ member ~ ", YamlSchema);");
                static if (udaID.length == 1)
                {
                    static assert(udaID.length == 1,
                            "Missing YamlSchema for " ~ T.stringof ~ "." ~ member);
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
                            mixin("setValue(yamlNode, section." ~ member ~ ");");
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

    File _file;
};
