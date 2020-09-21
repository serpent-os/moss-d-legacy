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

import moss.format.source.spec;
import moss.build.stage;

/**
 * The build context is responsible for building information on the
 * full build.
 */
struct BuildContext
{

public:

    /**
     * Construct a new BuildContext using the given (parsed) spec file.
     */
    this(Spec* spec, string architecture)
    {
        this._spec = spec;
        this._architecture = architecture;

        /* Construct stages based on available BuildDefinitions */
        insertStage("setup");
        insertStage("build");
        insertStage("install");

        import std.stdio;
    }

    /**
     * Return the architecture for this Build Context
     */
    pure final @property string architecture() @safe @nogc nothrow
    {
        return _architecture;
    }

private:

    final void insertStage(string name)
    {
        auto stage = ExecutionStage();
        stage.name = name;
        stage.workDir = "stage-" ~ name;
        stage.script = "";
        BuildDefinition buildDef = _spec.rootBuild;

        if (architecture in _spec.profileBuilds)
        {
            buildDef = _spec.profileBuilds[architecture];
        }

        switch (name)
        {
        case "setup":
            stage.script = buildDef.stepSetup;
            if (stage.script is null || stage.script == "null")
            {
                stage.script = _spec.rootBuild.stepSetup;
            }
            break;
        case "build":
            stage.script = buildDef.stepBuild;
            if (stage.script is null || stage.script == "null")
            {
                stage.script = _spec.rootBuild.stepBuild;
            }
            break;
        case "install":
            stage.script = buildDef.stepInstall;
            if (stage.script is null || stage.script == "null")
            {
                stage.script = _spec.rootBuild.stepInstall;
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

    Spec* _spec;
    string _architecture;
    ExecutionStage[] stages;
}
