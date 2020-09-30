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
        this._installRoot = context.rootDir.buildPath("install", architecture);

        /* Construct stages based on available BuildDefinitions */
        insertStage("setup");
        insertStage("build");
        insertStage("install");
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

private:

    final void insertStage(string name)
    {
        auto stage = ExecutionStage(&this, name);
        BuildDefinition buildDef = context.spec.rootBuild;

        if (architecture in context.spec.profileBuilds)
        {
            buildDef = context.spec.profileBuilds[architecture];
        }

        switch (name)
        {
        case "setup":
            stage.script = buildDef.stepSetup;
            if (stage.script is null || stage.script == "null")
            {
                stage.script = context.spec.rootBuild.stepSetup;
            }
            break;
        case "build":
            stage.script = buildDef.stepBuild;
            if (stage.script is null || stage.script == "null")
            {
                stage.script = context.spec.rootBuild.stepBuild;
            }
            break;
        case "install":
            stage.script = buildDef.stepInstall;
            if (stage.script is null || stage.script == "null")
            {
                stage.script = context.spec.rootBuild.stepInstall;
            }
            break;
        default:
            break;
        }

        if (stage.script is null || stage.script == "null")
        {
            return;
        }

        stages ~= stage;
    }

    BuildContext* _context;
    string _architecture;
    ExecutionStage[] stages;
    string _buildRoot;
    string _installRoot;
}
