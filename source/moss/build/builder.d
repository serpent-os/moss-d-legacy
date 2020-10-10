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
import moss.build.profile;
import moss.platform;

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

        auto buildRoot = getBuildRoot();
        context = BuildContext(&_specFile, buildRoot);

        auto plat = platform();

        /* Is emul32 supported for 64-bit OS? */
        if (plat.emul32)
        {
            auto emul32name = "emul32/" ~ plat.name;
            if (specFile.supportedArchitecture(emul32name)
                    || specFile.supportedArchitecture("emul32"))
            {
                addArchitecture(emul32name);
            }
        }

        /* Add builds if this is a supported platform */
        if (specFile.supportedArchitecture(plat.name) || specFile.supportedArchitecture("native"))
        {
            addArchitecture(plat.name);
        }
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
        profiles ~= new BuildProfile(&context, name);
    }

    /**
     * Full build cycle
     */
    final void build()
    {
        prepareRoot();
        prepareSources();
        buildProfiles();
        collectAssets();
        emitPackages();
    }

private:

    /**
     * Prepare our root filesystem for building on
     */
    final void prepareRoot() @system
    {
        import std.stdio;
        import std.file;

        writeln("Preparing root tree");

        if (context.rootDir.exists)
        {
            writeln("Removing old build tree");
            context.rootDir.rmdirRecurse();
        }

        mkdirRecurse(context.rootDir);
    }

    /**
     * Prepare and fetch any required sources
     */
    final void prepareSources() @system
    {
        import std.stdio;
        import moss.download;
        import std.algorithm;

        auto manager = new DownloadManager();
        manager.add(new DownloadStore(StoreType.System));
        manager.add(new DownloadStore(StoreType.User));

        /* Only work with plain sources for now */
        auto plains = _specFile.upstreams.values.filter!((u) => u.type == UpstreamType.Plain);

        /* Unfetched sources */
        auto fetchables = plains.filter!((u) => !manager.contains(u.plain.hash));
        foreach (u; fetchables)
        {
            manager.add(Download(u.uri, u.plain.hash));
        }

        manager.fetch();

        /* Now put them into place */
        foreach (s; plains)
        {
            import std.path : buildPath, baseName;
            import std.file : exists;

            /* Ensure we have a name for this source */
            if (s.plain.rename == null)
            {
                s.plain.rename = s.uri.baseName;
            }

            /* Now grab local full name including renamed path */
            string name = context.sourceDir.buildPath(s.plain.rename);
            manager.share(s.plain.hash, name);
        }

        writeln("Preparing sources");
    }

    /**
     * Build all of the given profiles
     */
    final void buildProfiles() @system
    {
        import std.stdio;

        writeln("Building profiles");

        foreach (ref p; profiles)
        {
            writefln(" > Building: %s", p.architecture);
            p.build();
        }
    }

    /**
     * Collect and analyse all assets
     */
    final void collectAssets() @safe
    {
        import std.stdio;

        writeln("Collecting assets");
    }

    /**
     * Emit all binary packages
     */
    final void emitPackages() @safe
    {
        import std.stdio;

        writeln("Emitting packages");
    }

    /**
     * Safely get the home root tree
     */
    final string getBuildRoot() @safe
    {
        import std.path;
        import std.file : exists;
        import std.exception : enforce;
        import std.string : format;

        auto hdir = expandTilde("~");
        enforce(hdir.exists, "Home directory not found!");

        return hdir.buildPath("moss", "buildRoot",
                "%s-%s".format(_specFile.source.name, _specFile.source.release));
    }

    /**
     * Update the underlying spec file
     */
    final @property void specFile(ref Spec s)
    {
        _specFile = s;
    }

    Spec _specFile;
    string[] architectures;
    BuildProfile*[] profiles;
    BuildContext context;
}
