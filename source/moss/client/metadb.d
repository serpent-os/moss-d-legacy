/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.metadb
 *
 * Metadata DB
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.metadb;
import moss.core.errors;
import moss.client.installation : Mutability;
import moss.db.keyvalue;
import moss.db.keyvalue.errors;
import moss.db.keyvalue.interfaces;
import moss.db.keyvalue.orm;

/**
 * Either works or it doesn't :)
 */
public alias MetaResult = Optional!(Success, Failure);

/**
 * Metadata encapsulation within a DB.
 *
 * Used for storing system wide (installed) packages as well
 * as powering "remotes".
 */
public final class MetaDB
{
    @disable this();

    /**
     * Construct a new MetaDB from the given path
     */
    this(string dbPath, Mutability mut) @safe
    {
        this.dbPath = dbPath;
        this.mut = mut;
    }

    /**
     * Connect to the underlying storage
     *
     * Returns: Success or Failure
     */
    MetaResult connect() @safe
    {
        return cast(MetaResult) fail("Not yet implemented");
    }

private:

    string dbPath;
    Mutability mut;
}
