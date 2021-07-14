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

module moss.db.interfaces;
public import std.typecons : Tuple;
public import moss.db.entry : DatabaseEntry;
public import moss.db : Datum;

public alias DatabaseEntryPair = Tuple!(DatabaseEntry, "entry", Datum, "value");

/**
 * Simple iteration API for buckets.
 */
public interface IIterable
{
    /**
     * Returns true if iteration is no longer possible or has ended
     */
    bool empty();

    /**
     * Return the entry pair at the front of the iterator
     */
    DatabaseEntryPair front();

    /**
     * Pop the current entry pair from the front of the iterator and seek to the
     * next one, if possible.
     */
    void popFront();
}

/**
 * Implementations should support reading within the current scope
 */
public interface IReadable
{
    /**
     * Retrieve a single value from the current namespace/scope
     */
    Datum get(scope Datum key);

    /**
     * Implementations must return a new iterator for reading through the
     * data.
     */
    @property IIterable iterator();
}

/**
 * Implementations should support writing within the current scope
 */
public interface IWritable
{
    /**
     * Set a single value within the current namespace/scope
     */
    void set(scope Datum key, scope Datum value);
}

/**
 * Specify the mutability of a connection to a database
 */
public enum DatabaseMutability
{
    ReadOnly = 0,
    ReadWrite = 1,
}

/**
 * The implementation is both readable and writable.
 */
public interface IReadWritable : IReadable, IWritable
{
}

/**
 * The Database interface specifies a contract to which our database
 * implementations should implement. By default they will have to implement
 * the Readable and Writeable interfaces for basic read/write functionality
 * but may also support batch operations.
 */
public abstract class Database : IReadWritable
{

    @disable this();

    /**
     * Property constructor for IDatabase to set the pathURI and mutability
     * properties internally prior to any connection attempt.
     */
    this(const(string) pathURI, DatabaseMutability mut = DatabaseMutability.ReadOnly)
    {
        _pathURI = pathURI;
        _mutability = mut;
    }

    /**
     * Ensure closure on GC
     */
    ~this()
    {
        close();
    }

    /**
     * Return a subset of the primary database that is namespaced with
     * a special bucket prefix or key.
     */
    abstract IReadWritable bucket(scope Datum prefix);

    /**
     * The path URI is set at construction time. This property returns the current value
     */
    pure @property const(string) pathURI() @safe @nogc nothrow
    {
        return _pathURI;
    }

    /**
     * Mutability is set at construction time. This property returns the current value
     */
    pure @property DatabaseMutability mutability() @safe @nogc nothrow
    {
        return _mutability;
    }

    /**
     * Implementations should close themselves.
     */
    abstract void close();

private:

    string _pathURI = null;
    DatabaseMutability _mutability = DatabaseMutability.ReadOnly;
}
