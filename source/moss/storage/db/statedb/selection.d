/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.storage.db.statedb.selection
 *
 * A Selection contains a pkgID along with a reason for its selection.
 *
 * The only currently available reason is manual selection by the administrator.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
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
