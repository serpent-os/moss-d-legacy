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
public import moss.format.source.buildDefinition;
public import moss.format.source.buildOptions;
public import moss.format.source.packageDefinition;
public import moss.format.source.schema;
public import moss.format.source.sourceDefinition;
public import moss.format.source.upstreamDefinition;

import dyaml;
import moss.format.source.ymlHelper;

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
     * Build options
     */
    BuildOptions options;

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

    UpstreamDefinition[string] upstreams;

    string[] architectures;

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

        enforce(_file.isOpen(), "Spec.parse(): File is not open");

        auto loader = Loader.fromFile(_file);
        auto root = loader.load();

        /* Parse the rootContext source */
        parseSection(root, source);
        parseSection(root, rootBuild);
        parseSection(root, rootPackage);
        parseSection(root, options);

        parsePackages(root);
        parseBuilds(root);
        parseUpstreams(root);
        parseArchitectures(root);
        parseTuningOptions(root);
    }

    /**
     * Returns true if the architecture is supported by this spec
     */
    pure final bool supportedArchitecture(string architecture)
    {
        import std.algorithm : canFind;

        return architectures.canFind(architecture);
    }

private:

    /**
     * Parse all tuning options
     */
    final void parseTuningOptions(ref Node node)
    {
        import std.exception : enforce;

        if (!node.containsKey("tuning"))
        {
            return;
        }

        Node root = node["tuning"];
        enforce(root.nodeID == NodeID.sequence, "tuning key should be a sequence of tuning options");

        /* Step through all items in root */
        foreach (ref Node k; root)
        {
            TuningSelection sel;

            if (k.nodeID == NodeID.scalar)
            {
                sel.type = TuningSelectionType.Enable;
                sel.name = k.as!string;
            }
            else if (k.nodeID == NodeID.mapping)
            {
                auto keys = k.mappingKeys;
                auto vals = k.mappingValues;
                enforce(keys.length == 1, "Each tuning option has 1 key only");
                enforce(vals.length == 1, "Each tuning option has 1 value only");

                auto name = keys[0].as!string;
                enforce(vals[0].nodeID == NodeID.scalar,
                        "Each tuning option must have 1 scalar value");
                auto val = vals[0];
                try
                {
                    auto bval = val.as!bool;
                    if (bval)
                    {
                        sel.type = TuningSelectionType.Enable;
                    }
                    else
                    {
                        sel.type = TuningSelectionType.Disable;
                    }
                }
                catch (Exception ex)
                {
                    sel.type = TuningSelectionType.Config;
                    sel.configValue = val.as!string;
                }
                sel.name = name;
            }
            else
            {
                enforce(0, "Unsupported value in tuning");
            }

            options.tuneSelections ~= sel;
        }
    }

    /**
     * Find all PackageDefinition instances and set them up
     */
    final void parsePackages(ref Node node)
    {
        import std.exception : enforce;

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

    final void parseArchitectures(ref Node node)
    {
        import std.exception : enforce;

        if (!node.containsKey("architectures"))
        {
            import moss.platform;

            auto plat = platform();
            auto emul32name = "emul32/" ~ plat.name;

            /* If "emul32" is enabled, add the emul32 architecture */
            if (node.containsKey("emul32"))
            {
                Node emul32n = node["emul32"];
                enforce(emul32n.nodeID == NodeID.scalar, "emul32 must be a boolean scalar value");

                /* Enable the host architecture + emul32 */
                if (emul32n.as!bool == true)
                {
                    architectures ~= emul32name;
                }
            }

            /* Add native architecture */
            architectures ~= plat.name;
            return;
        }

        /* Fine grained control, requiring "emul32/x86_64", etc */
        setValueArray(node["architectures"], architectures);
    }

    /**
     * Find all BuildDefinition instances and set them up
     */
    final void parseBuilds(ref Node node)
    {
        import std.exception : enforce;
        import std.string : startsWith;

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

        /* Find emul32 definition if it exists */
        BuildDefinition* emul32 = null;
        if ("emul32" in profileBuilds)
        {
            emul32 = &profileBuilds["emul32"];
        }

        /* Automatically parent profiles now */
        foreach (const string k; profileBuilds.keys)
        {
            auto v = &profileBuilds[k];
            if (k.startsWith("emul32/") && emul32 !is null)
            {
                v.parent = emul32;
            }
            else
            {
                v.parent = &rootBuild;
            }
        }
    }

    /**
     * Find all UpstreamDefinition instances and set them up
     */
    final void parseUpstreams(ref Node node)
    {
        import std.exception : enforce;
        import std.algorithm : startsWith;

        if (!node.containsKey("upstreams"))
        {
            return;
        }

        Node root = node["upstreams"];
        enforce(root.nodeID == NodeID.sequence,
                "upstreams key should be a sequence of upstream definitions");

        foreach (ref Node k; root)
        {
            foreach (ref Node c, ref Node v; k)
            {
                UpstreamDefinition ups;
                ups.uri = c.as!string;

                if (ups.uri.startsWith("git|"))
                {
                    ups.uri = ups.uri[4 .. $];
                    ups.type = UpstreamType.Git;
                }

                enforce(v.nodeID == NodeID.scalar || v.nodeID == NodeID.mapping,
                        "upstream definition should be a single value or mapping");
                final switch (ups.type)
                {
                case UpstreamType.Plain:
                    if (v.nodeID == NodeID.scalar)
                    {
                        ups.plain.hash = v.as!string;
                    }
                    else
                    {
                        parseSection(v, ups.plain);
                    }
                    break;
                case UpstreamType.Git:
                    if (v.nodeID == NodeID.scalar)
                    {
                        ups.git.refID = v.as!string;
                    }
                    else
                    {
                        parseSection(v, ups.git);
                    }
                    break;
                }

                upstreams[ups.uri] = ups;
            }
        }
    }

    File _file;
};
