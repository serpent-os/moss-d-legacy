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

module moss.format.source.upstreamDefinition;

public import moss.format.source.schema;

/**
 * Currently supported upstream types
 */
enum UpstreamType
{
    Plain = 0,
    Git,
}

/**
 * A Plain Upstream is a simple URI, such as a tarball.
 * By default a plain upstream is unpacked and retains the
 * same path as the URI dictates.
 */
struct PlainUpstreamDefinition
{
    /** Checksum for the origin */
    @YamlSchema("hash", true) string hash;

    /** New name for the source in case of conflicts */
    @YamlSchema("rename") string rename = null;

    /** Whether to automatically unpack the source. */
    @YamlSchema("unpack") bool unpack = true;
}

/**
 * A Git upstream points to a remote git repository, which
 * by default will attempt a shallow clone.
 */
struct GitUpstreamDefinition
{
    /** The ref to clone (i.e. branch, commit) */
    @YamlSchema("ref", true) string refID;
}

/**
 * UpstreamDefinition is a tagged union making it easier to manage
 * various upstream specific properties.
 */
struct UpstreamDefinition
{
    UpstreamType type = UpstreamType.Plain;

    /** Origin URI, set from the YAML key automatically */
    string uri;

    union
    {
        PlainUpstreamDefinition plain;
        GitUpstreamDefinition git;
    };
};
