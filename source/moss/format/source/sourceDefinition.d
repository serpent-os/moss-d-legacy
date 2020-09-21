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

module moss.format.source.sourceDefinition;

public import moss.format.source.schema;
public import std.stdint : int64_t;

/**
 * Source definition details the root name, version, etc, and where
 * to get sources
 */
struct SourceDefinition
{
    /**
     * The base name of the software package. This should follow both
     * the upstream name and the packaging policies.
     */
    @YamlSchema("name", true) string name;

    /**
     * A version identifier for this particular release of the software.
     * This has no bearing on selections, and is only provided to allow
     * humans to understand the version of software being included.
     */
    @YamlSchema("version", true) string versionIdentifier;

    /**
     * Releases help determine priority of updates for packages of the
     * same origin. Bumping the release number will ensure an update
     * is performed.
     */
    @YamlSchema("release", true) int64_t release;
};
