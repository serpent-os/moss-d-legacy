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

module moss.db;

import moss.format.binary;
import moss.format.binary.payload;
import serpent.ecs;

/**
 * Base class for all Moss Databases
 *
 * Simply provides just enough sauce to make it possible to (ab)use a moss
 * archive + payload as a basic database which is loaded to/from an ECS.
 *
 * Implementations should mostly use KvPairPayload, though its more than
 * possible to use any Payload with a hot-load/write function (i.e. no local
 * retention) with MossDB, by making use of the userData pointer exposed to the
 * payload, and implementing the bulk of the "DB" logic in the MossDB subclass.
 */
public abstract class MossDB
{

    @disable this();

    /**
     * Super constructor for MossDB, expects a valid EntityManager
     */
    this(EntityManager entityManager)
    {
        _entityManager = entityManager;
    }

    /**
     * Return the EntityManager used for in-memory storage
     */
    pragma(inline, true) pure @property EntityManager entityManager() @safe @nogc nothrow
    {
        return _entityManager;
    }

    /**
     * Commit the db to disk using the Payload mechanism
     * This will force another cycle of the EntityManager
     */
    final void commit()
    {
        import std.exception : enforce;
        import std.string : format;
        import std.file : rename;

        enforce(filePath !is null, "MossDB.commit(): No filePath set");

        auto tmpPath = "%s-tmpFile".format(filePath);
        auto writer = new Writer(File(tmpPath, "wb"));
        writer.fileType = MossFileType.Database;
        scope (exit)
        {
            writer.close();
            tmpPath.rename(filePath);
        }
        auto payload = this.preparePayload();
        payload.userData = cast(void*) this;
        entityManager.step();
        writer.addPayload(payload);
        writer.flush();
    }

    /**
     * Drop all entities with the matching component
     */
    void dropEntitiesWithComponents(T...)()
    {
        import std.algorithm : each;

        auto view = View!ReadWrite(entityManager);
        view.withComponents!T
            .each!((e) => view.killEntity(e[0].id));
        entityManager.step();
    }

    /**
     * Reload all entries from the DB on disk
     */
    void reload(T)()
    {
        import std.file : exists;
        import std.exception : enforce;

        enforce(filePath !is null, "MossDB.reload(): No filePath set");

        if (!filePath.exists)
        {
            return;
        }

        clear();

        auto reader = new Reader(File(filePath, "rb"));
        reader.setUserData!T(cast(void*) this);
        enforce(reader.fileType == MossFileType.Database,
                "MossDB.reload(): Non-database file not supported");

        /* Force a load */
        reader.payload!T();
    }

    /**
     * Implementations must override this method so that any old entities can be
     * removed from the ECS before loading new ones
     */
    abstract void clear();

    /**
     * Implementations should prepare a payload and return it here
     */
    abstract Payload preparePayload();

    /**
     * Return the filePath for this database
     */
    pure final @property const(string) filePath() @safe @nogc nothrow
    {
        return _filePath;
    }

protected:

    pure final @property void filePath(string newPath) @safe @nogc nothrow
    {
        _filePath = newPath;
    }

package:

    /**
     * Set the underlying entity manager for in-memory storage
     */
    pure @property void entityManager(EntityManager entityManager) @safe @nogc nothrow
    {
        _entityManager = entityManager;
    }

private:

    EntityManager _entityManager = null;
    string _filePath = null;
}
