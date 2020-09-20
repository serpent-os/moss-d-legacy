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

/**
 * A Build Definition provides the relevant steps to complete production
 * of a package. All steps are optional.
 */
struct BuildDefinition
{
    string stepSetup;
    string stepBuild;
    string stepInstall;
    string[] buildDependencies;
};

struct PackageDefinition
{
    string summary;
    string description;
    string[] runtimeDependencies;
};

/**
 * Source definition details the root name, version, etc, and where
 * to get sources
 */
struct SourceDefinition
{
    string name;
    string versionIdentifier;
    int64_t release;
};

/**
 * A Spec is a stone specification file. It is used to parse a "stone.yml"
 * formatted file with the relevant meta-data and steps to produce a binary
 * package.
 */
struct Spec
{

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

};
