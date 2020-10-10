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

module moss.build.context;

import moss.format.source.macros;
import moss.format.source.spec;
import moss.format.source.script;

/**
 * The BuildContext holds global configurations and variables needed to complete
 * all builds.
 */
struct BuildContext
{
    /**
     * Construct a new BuildContect
     */
    this(Spec* spec, string rootDir)
    {
        import std.conv : to;
        import std.string : format;
        import std.path : buildPath;

        this._spec = spec;
        this._rootDir = rootDir;
        this._sourceDir = rootDir.buildPath("sources");

        this.loadMacros();
    }

    /**
     * Return the root directory
     */
    pure final @property const string rootDir() @safe @nogc nothrow
    {
        return _rootDir;
    }

    pure final @property const string sourceDir() @safe @nogc nothrow
    {
        return _sourceDir;
    }

    /**
     * Return the underlying specfile
     */
    pure final @property Spec* spec() @safe @nogc nothrow
    {
        return _spec;
    }

    /**
     * Return the number of build jobs
     */
    pure final @property int jobs() @safe @nogc nothrow
    {
        return _jobs;
    }

    /**
     * Set the number of build jobs
     */
    final @property void jobs(int j) @safe @nogc nothrow
    {
        _jobs = j;
    }

    /**
     * Prepare a ScriptBuilder
     */
    final void prepareScripts(ref ScriptBuilder sbuilder, string architecture)
    {
        import std.stdio : writefln;
        import std.conv : to;

        string[] arches = ["base", architecture];

        sbuilder.addDefinition("name", spec.source.name);
        sbuilder.addDefinition("version", spec.source.versionIdentifier);
        sbuilder.addDefinition("release", to!string(spec.source.release));
        sbuilder.addDefinition("jobs", to!string(jobs));
        sbuilder.addDefinition("sources", _sourceDir);

        foreach (ref arch; arches)
        {
            auto archFile = defFiles[arch];
            sbuilder.addFrom(archFile);
        }

        foreach (ref action; actionFiles)
        {
            sbuilder.addFrom(action);
        }
    }

private:

    /**
     * Load all supportable macros
     */
    final void loadMacros()
    {
        import std.file;
        import std.path : buildPath, dirName, baseName;
        import moss.platform;
        import std.string : format;
        import std.exception : enforce;

        MacroFile* file = null;

        string resourceDir = "/usr/share/moss/macros";
        string actionDir = null;
        string localDir = dirName(thisExePath).buildPath("..", "data", "macros");

        /* Prefer local macros */
        if (localDir.exists())
        {
            resourceDir = localDir;
        }

        auto plat = platform();
        actionDir = resourceDir.buildPath("actions");

        /* Architecture specific YMLs that MUST exist */
        string baseYml = resourceDir.buildPath("base.yml");
        string nativeYml = resourceDir.buildPath("%s.yml".format(plat.name));
        string emulYml = resourceDir.buildPath("emul32", "%s.yml".format(plat.name));

        enforce(baseYml.exists, baseYml ~ " file cannot be found");
        enforce(nativeYml.exists, nativeYml ~ " cannot be found");
        if (plat.emul32)
        {
            enforce(emulYml.exists, emulYml ~ " cannot be found");
        }

        /* Load base YML */
        file = new MacroFile(File(baseYml));
        file.parse();
        defFiles["base"] = file;

        /* Load arch specific */
        file = new MacroFile(File(nativeYml));
        file.parse();
        defFiles[plat.name] = file;

        /* emul32? */
        if (plat.emul32)
        {
            file = new MacroFile(File(emulYml));
            file.parse();
            defFiles["emul32/%s".format(plat.name)] = file;
        }

        if (!actionDir.exists)
        {
            return;
        }

        /* Load all the action files in */
        foreach (nom; dirEntries(actionDir, "*.yml", SpanMode.shallow, false))
        {
            if (!nom.isFile)
            {
                continue;
            }
            auto name = nom.name.baseName[0 .. $ - 4];
            file = new MacroFile(File(nom.name));
            file.parse();
            actionFiles ~= file;
        }
    }

    string _rootDir;
    string _sourceDir;
    Spec* _spec;
    MacroFile*[string] defFiles;
    MacroFile*[] actionFiles;
    int _jobs = 1;
}
