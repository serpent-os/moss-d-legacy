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

module moss.manager.transaction;

public import moss.manager.state : State;

/**
 * Specific operation type
 */
package final enum OpType
{
    InstallLocal = 0,
}

/**
 * Tagged structure to build operation lists from
 */
package struct TransactionOp
{
    OpType type;
    string data;

    this(OpType type, const(string) data)
    {
        this.type = type;
        this.data = data;
    }
}

/**
 * A State is a view of a current or future installation state within the
 * target system.
 */
public final class Transaction
{

    /**
     * Condense this transaction into one or more possible outcomes states,
     * accounting for dependency differences
     */
    State[] end() @safe
    {
        return [new State(baseState.manager, 0)];
    }

    /**
     * Return the base state that this transaction is modifying
     */
    pure @property State baseState() @safe @nogc nothrow
    {
        return _baseState;
    }

    @disable this();

    /**
     * Add set of local archives to the queue
     */
    void installLocalArchive(const(string) path)
    {
        opQueue ~= TransactionOp(OpType.InstallLocal, path);
    }

package:

    /**
     * Protect constructor
     */
    this(State baseState) @safe
    {
        this._baseState = baseState;
    }

    /**
     * Update the baseState property
     */
    pure @property void baseState(State s) @safe @nogc nothrow
    {
        _baseState = s;
    }

private:

    State _baseState;
    TransactionOp[] opQueue;
}
