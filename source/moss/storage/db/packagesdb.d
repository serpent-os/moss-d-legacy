/*
 * This file is part of moss.
 *
 * Copyright © 2020-2021 Serpent OS Developers
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

module moss.storage.db.packagesdb;

public import moss.storage.db.metadb;
public import moss.deps.registry.plugin;

import moss.context;

/**
 * SystemPackagesDB tracks packages installed across various states and doesn't specifically
 * link them to any given state. Instead it retains MetaData for locally installed
 * candidates to provide a system level of resolution for packages no longer referenced
 * from a repository.
 */
public final class SystemPackagesDB : MetaDB
{
    /**
     * Construct a new SystemPackagesDB which will immediately force a reload of the
     * on-disk database if it exists
     */
    this()
    {
        super(context().paths.db.buildPath("packagesDB"));
    }
}
