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

module moss.build.profile;

import moss.format.source.spec;
import moss.format.source.script;
import moss.build.context;
import moss.build.stage;

import std.path : buildPath;

/**
 * A build profile is generated for each major build profile in the
 * source configuration, i.e. x86_64, emul32, etc.
 *
 * It is tied to a specific architecture and will be seeded from
 * the architecture-specific build options.
 */
struct BuildProfile
{

public:

    /**
     * Construct a new BuildProfile using the given (parsed) spec file.
     */
    this(BuildContext* context, string architecture)
    {
        this._context = context;
        this._architecture = architecture;
        this._buildRoot = context.rootDir.buildPath("build", architecture);
        this._installRoot = context.rootDir.buildPath("install");

        StageType[] stages;

        /* CSPGO is only available with LLVM toolchain */
        bool multiStagePGO = (context.spec.options.toolchain == "llvm"
                && context.spec.options.csgpo == true);

        /* PGO specific staging */
        if (hasPGOWorkload)
        {
            StageType generationFlags = StageType.ProfileGenerate;
            if (multiStagePGO)
            {
                generationFlags |= StageType.ProfileStage1;
            }

            /* Always construct a stage1 */
            stages = [
                StageType.Prepare | generationFlags,
                StageType.Setup | generationFlags,
                StageType.Build | generationFlags,
                StageType.Workload | generationFlags,
            ];

            /* Mulitistage uses + refines */
            if (multiStagePGO)
            {
                stages ~= [
                    StageType.Prepare | StageType.ProfileGenerate | StageType.ProfileStage2,
                    StageType.Setup | StageType.ProfileGenerate | StageType.ProfileStage2,
                    StageType.Build | StageType.ProfileGenerate | StageType.ProfileStage2,
                    StageType.Workload | StageType.ProfileGenerate | StageType.ProfileStage2,
                ];
            }

            /* Always add the use/final stage */
            stages ~= [
                StageType.Prepare | StageType.ProfileUse,
                StageType.Setup | StageType.ProfileUse,
                StageType.Build | StageType.ProfileUse,
                StageType.Install | StageType.ProfileUse,
                StageType.Check | StageType.ProfileUse,
            ];
        }
        else
        {
            /* No PGO, just execute stages */
            stages = [
                StageType.Prepare, StageType.Setup, StageType.Build,
                StageType.Install, StageType.Check,
            ];
        }

        /* Lights, cameras, action */
        foreach (s; stages)
        {
            insertStage(s);
        }

    }

    /**
     * Return the underlying context
     */
    pure final @property BuildContext* context() @safe @nogc nothrow
    {
        return _context;
    }

    /**
     * Return the architecture for this Build Context
     */
    pure final @property string architecture() @safe @nogc nothrow
    {
        return _architecture;
    }

    /**
     * Return the build root directory for this profile
     */
    pure final @property string buildRoot() @safe @nogc nothrow
    {
        return _buildRoot;
    }

    /**
     * Return the installation root directory for this profile
     */
    pure final @property string installRoot() @safe @nogc nothrow
    {
        return _installRoot;
    }

    /**
     * Request for this profile to now build
     */
    final void build()
    {
        foreach (ref e; stages)
        {
            import std.stdio;
            import std.array;

            auto builder = ScriptBuilder();
            prepareScripts(builder);
            auto scripted = builder.process(e.script).replace("%%", "%");
            writefln("Generating script: %s\n%s\n", e.name, scripted);
        }
    }

    /**
     * Prepare a script builder for use
     */
    final void prepareScripts(ref ScriptBuilder sbuilder)
    {
        auto pgoStage1Dir = buildRoot ~ "-pgo1";
        auto pgoStage2Dir = buildRoot ~ "-pgo2";

        sbuilder.addDefinition("installdir", installRoot);
        sbuilder.addDefinition("builddir", buildRoot);

        /* Set the relevant compilers */
        if (context.spec.options.toolchain == "llvm")
        {
            sbuilder.addDefinition("compiler_c", "clang");
            sbuilder.addDefinition("compiler_cxx", "clang++");
            sbuilder.addDefinition("compiler_cpp", "clang-cpp");
        }
        else
        {
            sbuilder.addDefinition("compiler_c", "gcc");
            sbuilder.addDefinition("compiler_cxx", "g++");
            sbuilder.addDefinition("compiler_cpp", "cpp");
        }

        sbuilder.addDefinition("pgo_stage1_dir", pgoStage1Dir);
        sbuilder.addDefinition("pgo_stage2_dir", pgoStage2Dir);

        /* TODO: Fix to not suck */
        sbuilder.addDefinition("cflags", "");
        sbuilder.addDefinition("cxxflags", "");
        sbuilder.addDefinition("ldflags", "");

        context.prepareScripts(sbuilder, architecture);
    }

private:

    /**
     * Return true if a PGO workload is found for this architecture
     */
    final bool hasPGOWorkload() @safe
    {
        import std.string : startsWith;

        BuildDefinition buildDef = context.spec.rootBuild;
        if (architecture in context.spec.profileBuilds)
        {
            buildDef = context.spec.profileBuilds[architecture];
        }
        else if (architecture.startsWith("emul32/") && "emul32" in context.spec.profileBuilds)
        {
            buildDef = context.spec.profileBuilds["emul32"];
        }

        return buildDef.workload() != null;
    }

    /**
     * Insert a stage for processing + execution
     *
     * We'll only insert stages if we find a relevant build description for it,
     * and doing so will result in parent traversal of profiles (i.e. root namespace
     * and emul32 namespace)
     */
    final void insertStage(StageType t)
    {
        import std.string : startsWith;

        string name = null;

        string script = null;

        /* Default to root namespace */
        BuildDefinition buildDef = context.spec.rootBuild;

        /* Find specific definition for stage, or an appropriate parent */
        if (architecture in context.spec.profileBuilds)
        {
            buildDef = context.spec.profileBuilds[architecture];
        }
        else if (architecture.startsWith("emul32/") && "emul32" in context.spec.profileBuilds)
        {
            buildDef = context.spec.profileBuilds["emul32"];
        }

        /* Check core type of stage */
        if ((t & StageType.Setup) == StageType.Setup)
        {
            script = buildDef.setup();
        }
        else if ((t & StageType.Build) == StageType.Build)
        {
            script = buildDef.build();
        }
        else if ((t & StageType.Install) == StageType.Install)
        {
            script = buildDef.install();
        }
        else if ((t & StageType.Check) == StageType.Check)
        {
            script = buildDef.check();
        }
        else if ((t & StageType.Workload) == StageType.Workload)
        {
            script = buildDef.workload();
        }
        else if ((t & StageType.Prepare) == StageType.Prepare)
        {
            script = genPrepareScript();
        }

        /* Need valid script to continue */
        if (script is null)
        {
            return;
        }

        auto stage = new ExecutionStage(&this, t);
        stage.script = script;
        stages ~= stage;
    }

    /**
     * Generate preparation script
     *
     * The sole purpose of this internal script is to make the sources
     * available to the current build in their extracted/exploded form
     */
    final string genPrepareScript() @system
    {
        import std.string : endsWith;
        import std.path : baseName;

        string ret = "";

        /* Push commands to extract a zip */
        void extractZip(ref UpstreamDefinition u)
        {
            ret ~= "unzip -d . \"%(sources)/" ~ u.plain.rename
                ~ "\" || (echo \"Failed to extract archive\"; exit 1);";
        }

        /* Push commands to extract a tar */
        void extractTar(ref UpstreamDefinition u)
        {
            ret ~= "tar xf \"%(sources)/" ~ u.plain.rename
                ~ "\" -C . || (echo \"Failed to extract archive\"; exit 1);";
        }

        foreach (source; context.spec.upstreams)
        {
            final switch (source.type)
            {
            case UpstreamType.Plain:
                if (!source.plain.unpack)
                {
                    continue;
                }
                /* Ensure a target name */
                if (source.plain.rename is null)
                {
                    source.plain.rename = source.uri.baseName;
                }
                if (source.plain.rename.endsWith(".zip"))
                {
                    extractZip(source);
                }
                else
                {
                    extractTar(source);
                }
                break;
            case UpstreamType.Git:
                assert(0, "GIT SOURCE NOT YET SUPPORTED");
            }
        }

        return ret == "" ? null : ret;
    }

    BuildContext* _context;
    string _architecture;
    ExecutionStage*[] stages;
    string _buildRoot;
    string _installRoot;
}
