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

module moss.controller;

import moss.context;
import moss.jobs;

import moss.storage.pool;
import moss.storage.db.cachedb;
import moss.storage.db.installdb;
import moss.storage.db.layoutdb;
import moss.storage.db.statedb;
import moss.query;

/**
 * MossController is required to access the underlying Moss resources and to
 * manipulate the filesystem in any way.
 */
final class MossController
{
    /**
     * Construct a new MossController
     */
    this()
    {
        diskPool = new DiskPool();
        cacheDB = new CacheDB();
        layoutDB = new LayoutDB();
        stateDB = new StateDB();
        installDB = new InstallDB();
        query = new QueryManager();

        /* TODO: Register job types and processors */
    }

    /**
     * Close the MossController and all resources
     */
    void close()
    {
        cacheDB.close();
        layoutDB.close();
        stateDB.close();
        installDB.close();
    }

private:

    DiskPool diskPool = null;
    CacheDB cacheDB = null;
    LayoutDB layoutDB = null;
    StateDB stateDB = null;
    InstallDB installDB = null;
    QueryManager query = null;

}
