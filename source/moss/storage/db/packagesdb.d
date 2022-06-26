/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.storage.db.packages.db
 *
 * Defines SystemPackagesDB, which tracks packages installed across various
 * states.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
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
        super(join([context().paths.db, "packagesDB"], "/"));
    }
}
