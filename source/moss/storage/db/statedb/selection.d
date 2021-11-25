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

module moss.storage.db.statedb.selection;

import moss.core.encoding;
import moss.db.encoding;
import std.typecons : Nullable;

/**
 * Reason for a target being specified
 */
public enum SelectionReason
{
    /**
     * Installed manually at request of administrator
     */
    ManuallyInstalled = 0,
}

/**
 * A Selection is specially encoded to have a reason for selection, etc.
 */
public struct Selection
{
    /**
     * Target (packageID) of this selection
     */
    const(string) target = null;

    /**
     * Reason for selection
     */
    SelectionReason reason = SelectionReason.ManuallyInstalled;

    /**
     * For now just encode the reason as target is in the key
     */
    ImmutableDatum mossEncode()
    {
        return reason.mossEncode();
    }

    /**
     * Just decode reason
     */
    void mossDecode(in ImmutableDatum rawBytes)
    {
        reason.mossDecode(rawBytes);
    }
}

public alias NullableSelection = Nullable!(Selection, Selection.init);
