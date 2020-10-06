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

module moss.format.source.buildDefinition;

public import moss.format.source.schema;

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
    @YamlSchema("setup") string stepSetup = null;

    /**
     * Build step.
     *
     * These instructions should begin compilation of the source, such
     * as with "make".
     */
    @YamlSchema("build") string stepBuild = null;

    /**
     * Install step.
     *
     * This is the final build step, and should be used to install the
     * files produced by the previous steps into the target "collection"
     * area, ready to be converted into a package.
     */
    @YamlSchema("install") string stepInstall = null;

    /**
     * Check step.
     *
     * We can now ensure consistency of the package by running a test
     * suite before attempting to deploy it to the users.
     */
    @YamlSchema("check") string stepCheck = null;

    /**
     * The workload is executed for Profile Guided Optimisation builds.
     */
    @YamlSchema("workload") string stepWorkload = null;

    /**
     * Build dependencies
     *
     * We list build dependencies in a format suitable for consumption
     * by the package manager.
     */
    @YamlSchema("builddeps", false, YamlType.Array) string[] buildDependencies;

    /** Parent definition to permit lookups */
    BuildDefinition* parent = null;

    /**
     * Return the relevant setup step
     */
    final string setup() @safe
    {
        BuildDefinition* node = &this;

        while (node !is null)
        {
            if (node.stepSetup != null && node.stepSetup != "(null)" && node.stepSetup != "")
            {
                return node.stepSetup;
            }
            node = node.parent;
        }
        return null;
    }

    /**
     * Return the relevant build step
     */
    final string build() @safe
    {
        BuildDefinition* node = &this;

        while (node !is null)
        {
            if (node.stepBuild != null && node.stepBuild != "(null)" && node.stepBuild != "")
            {
                return node.stepBuild;
            }
            node = node.parent;
        }
        return null;
    }

    /**
     * Return the relevant install step
     */
    final string install() @safe
    {
        BuildDefinition* node = &this;

        while (node !is null)
        {
            if (node.stepInstall != null && node.stepInstall != "(null)" && node.stepInstall != "")
            {
                return node.stepInstall;
            }
            node = node.parent;
        }
        return null;
    }

    /**
     * Return the relevant check step
     */
    final string check() @safe
    {
        BuildDefinition* node = &this;

        while (node !is null)
        {
            if (node.stepCheck != null && node.stepCheck != "(null)" && node.stepCheck != "")
            {
                return node.stepCheck;
            }
            node = node.parent;
        }
        return null;
    }

    /**
     * Return the relevant PGO workload step
     */
    final string workload() @safe
    {
        BuildDefinition* node = &this;

        while (node !is null)
        {
            if (node.stepWorkload != null && node.stepWorkload != "(null)" && node.stepWorkload
                    != "")
            {
                return node.stepWorkload;
            }
            node = node.parent;
        }
        return null;
    }
};
