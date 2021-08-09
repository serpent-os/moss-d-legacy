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

module moss.client.direct;

import moss.context;
import std.exception : enforce;
import std.file : exists;

public import moss.client : MossClient;

import moss.storage.db.statedb;

/**
 * The direct implementation for MossClient
 *
 * This (default) implementation works directly on the local filesystems
 * and has no broker mechanism
 */
public final class DirectMossClient : MossClient
{

    /**
     * Construct a new Direct moss client
     */
    this() @trusted
    {
        enforce(context.paths.root !is null, "context.paths.root() is null!");
        enforce(context.paths.root.exists, "context.paths.root() does not exist!");

        /* Enforce creation of all required paths */
        context.paths.mkdirs();

        stateDB = new StateDB();
        stateDB.reloadDB();
    }

    override void installLocalArchives(string[] archivePaths)
    {
        import std.stdio : writefln;

        foreach (p; archivePaths)
        {
            writefln("Failed to install: %s", p);
        }
    }

    override void close()
    {
        stateDB.close();
    }

private:

    StateDB stateDB = null;
}
