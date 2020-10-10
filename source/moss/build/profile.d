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

        /* PGO handling */
        pgoStage1Dir = buildRoot ~ "-pgo1";
        pgoStage2Dir = buildRoot ~ "-pgo2";

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
     * Write the temporary script to disk, then execute it.
     */
    final void runStage(ExecutionStage* stage, string workDir, ref string script) @system
    {
        import core.sys.posix.stdlib;
        import std.stdio;
        import std.string;
        import core.stdc.string;
        import core.sys.posix.unistd;
        import std.file;
        import std.exception : enforce;

        auto tmpname = "/tmp/moss-stage-%s-XXXXXX".format(stage.name);
        auto copy = new char[tmpname.length + 1];
        copy[0 .. tmpname.length] = tmpname[];
        copy[tmpname.length] = '\0';
        int fd = mkstemp(copy.ptr);

        File fi;
        fi.fdopen(fd, "w");

        scope (exit)
        {
            fi.close();
            remove(cast(string) copy[0 .. copy.length - 1]);
        }

        /* Write + flush */
        fi.write(script);
        fi.flush();
        fflush(fi.getFP);

        /* Execute, TODO: Fix environment */
        import std.process;

        auto config = Config.retainStderr | Config.retainStdout
            | Config.stderrPassThrough | Config.inheritFDs;
        auto prenv = cast(const(string[string])) null;

        auto args = ["/bin/sh", cast(string) copy[0 .. copy.length - 1]];

        auto id = spawnProcess(args, stdin, stdout, stderr, prenv, config, workDir);
        auto status = wait(id);
        enforce(status == 0, "Stage '%s' exited with code '%d'".format(stage.name, status));
    }

    /**
     * Request for this profile to now build
     */
    final void build()
    {
        import std.stdio;
        import std.array;
        import std.file : mkdirRecurse;

        bool preparedFS = false;

        foreach (ref e; stages)
        {
            string workdir = buildRoot;
            if (preparedFS)
            {
                workdir = getWorkDir();
            }

            /* Prepare the rootfs now */
            auto builder = ScriptBuilder();
            prepareScripts(builder, workdir);
            buildRoot.mkdirRecurse();

            auto scripted = builder.process(e.script).replace("%%", "%");

            /* Ensure PGO dirs are present if needed */
            if ((e.type & StageType.ProfileGenerate) == StageType.ProfileGenerate)
            {
                import std.file : mkdirRecurse;

                if ((e.type & StageType.ProfileStage2) == StageType.ProfileStage2)
                {
                    pgoStage2Dir.mkdirRecurse();
                }
                else
                {
                    pgoStage1Dir.mkdirRecurse();
                }
            }

            runStage(e, workdir, scripted);

            /* Did we prepare the fs for building? */
            if ((e.type & StageType.Prepare) == StageType.Prepare)
            {
                preparedFS = true;
            }
        }
    }

    /**
     * Throw an error if script building fails
     */
    final void validate()
    {
        foreach (ref e; stages)
        {
            ScriptBuilder builder;
            prepareScripts(builder, buildRoot);

            /* Throw script away, just ensure it can build */
            auto scripted = builder.process(e.script);
        }
    }

    /**
     * Prepare a script builder for use
     */
    final void prepareScripts(ref ScriptBuilder sbuilder, string workdir)
    {
        sbuilder.addDefinition("installdir", installRoot);
        sbuilder.addDefinition("builddir", buildRoot);
        sbuilder.addDefinition("workdir", workdir);

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

        /* Load system macros */
        context.prepareScripts(sbuilder, architecture);

        bakeFlags(sbuilder);

        /* Fully cooked */
        sbuilder.bake();
    }

private:

    /**
     * Specialist function to work with the ScriptBuilder in enabling a sane
     * set of build flags
     */
    final void bakeFlags(ref ScriptBuilder sbuilder) @safe
    {
        import moss.format.source.tuningFlag;
        import std.array : join;
        import std.algorithm;
        import std.array;
        import std.string : strip;

        /* Set toolchain type for flag probing */
        auto toolchain = context.spec.options.toolchain == "llvm" ? Toolchain.LLVM : Toolchain.GNU;

        /* Enable some flags */
        sbuilder.enableGroup("base");
        sbuilder.enableGroup("optimize");

        /* Fix up unique set of flags and stringify them */
        auto flagset = sbuilder.buildFlags();
        auto cflags = flagset.map!((f) => f.cflags(toolchain).strip)
            .array
            .uniq
            .filter!((e) => e.length > 1)
            .join(" ");
        auto cxxflags = flagset.map!((f) => f.cxxflags(toolchain).strip)
            .array
            .uniq
            .filter!((e) => e.length > 1)
            .join(" ");
        auto ldflags = flagset.map!((f) => f.ldflags(toolchain).strip)
            .array
            .uniq
            .filter!((e) => e.length > 1)
            .join(" ");

        sbuilder.addDefinition("cflags", cflags);
        sbuilder.addDefinition("cxxflags", cxxflags);
        sbuilder.addDefinition("ldflags", ldflags);
    }

    /**
     * Attempt to grab the workdir from the build tree
     *
     * Unless explicitly specified, it will be the first directory
     * entry within the build root
     */
    final string getWorkDir() @system
    {
        import std.file : dirEntries, SpanMode;
        import std.path : buildPath, baseName;
        import std.string : startsWith;

        /* TODO: Support workdir variable in spec and verify it exists */
        auto items = dirEntries(buildRoot, SpanMode.shallow, false);
        foreach (item; items)
        {
            auto name = item.name.baseName;
            if (!item.name.startsWith("."))
            {
                return buildRoot.buildPath(name);
            }
        }

        return buildRoot;
    }

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
    string pgoStage1Dir;
    string pgoStage2Dir;
}
