/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.installdb
 *
 * A MetaDB encapsulation to store current installation metadata
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.installdb;

import moss.client.metadb;
import moss.client.installation;
import moss.format.binary.payload.meta : MetaPayload;

/**
 * Wraps MetaDB to allow installing/retrieval of metadata.
 */
public final class InstallDB
{

    @disable this();

    /**
     * Construct a new InstallDB from the given installation
     */
    this(Installation installation) @safe
    {
        this.installation = installation;
        auto dbPath = installation.dbPath("install");
        this.db = new MetaDB(dbPath, installation.mutability);
    }

    /**
     * Install via MetaDB
     */
    auto install(scope MetaPayload mp) @safe
    {
        return db.install(mp);
    }

    /**
     * Connect to the system installation database
     */
    auto connect() @safe
    {
        return db.connect();
    }

    /**
     * Close the MetaDB
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
    MetaDB db;
}
