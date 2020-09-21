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

module moss.format.source.packageDefinition;

public import moss.format.source.schema;

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
