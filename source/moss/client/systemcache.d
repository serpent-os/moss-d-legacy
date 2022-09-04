/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.systemcache
 *
 * Asset management
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.systemcache;

public import moss.core.errors;
public import std.sumtype;
public import moss.client.installation;

import moss.db.keyvalue;
import moss.db.keyvalue.errors;
import moss.db.keyvalue.orm;

/**
 * All SystemCache operations return a CacheResult
 */
public alias CacheResult = Optional!(Success, Failure);

/**
 * The SystemCache is the global disk pool of assets which
 * are shared between all filesystem transactions (install roots).
 * The implementation consists of naming facilities, methods to then
 * cache an asset, and finally some reference counting semantics.
 */
public final class SystemCache
{

    @disable this();

    /**
     * Construct a new SystemCache
     *
     * Params:
     *      installation = Initialised Installation instance
     */
    this(Installation installation) @safe
    {
        this.installation = installation;
    }

    /**
     * Attempt to open the SystemCache
     *
     * Returns: Success or Failure
     */
    CacheResult open() @safe
    {
        return cast(CacheResult) fail("Not yet implemented");
    }

    /**
     * Close the underlying resources
     */
    void close() @safe
    {
        if (db is null)
        {
            return;
        }
        db.close();
        db = null;
    }

private:

    Installation installation;
    Database db;
}
