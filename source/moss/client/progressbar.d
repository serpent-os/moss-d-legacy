/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.progressbar
 *
 * Console-based progress-bar
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.progressbar;

public import moss.client.renderer;

import std.string : format;
import moss.client.ui;

/**
 * Basic ProgressBar implementation
 */
public final class ProgressBar : Renderable
{
    /**
     * Render due to invalidation
     */
    override string render() @safe
    {
        if (total <= 0)
        {
            return "";
        }
        auto pct = _current / _total;
        if (pct < 0.0 || pct > 1.0)
        {
            return "";
        }
        static const totalElements = 24;
        const auto fraction = (totalElements * pct);
        static const barEmpty = "◻";
        static const barFull = "◼";

        string msg = "";
        foreach (i; 0 .. totalElements)
        {
            if (fraction < i)
            {
                msg ~= barEmpty;
            }
            else
            {
                msg ~= barFull;
            }
        }
        auto percentage = cast(int)(pct * 100.0);
        auto pctLabel = format!"%2d%%"(cast(int)(pct * 100.0));
        auto pctString = format!"%*s%s"(5 - pctLabel.length, " ", pctLabel);
        return format!" %s %s %s"(Text(msg).fg(_special ? Color.Green
                : Color.Cyan).attr(Attribute.Bold), Text(pctString),
                Text(_label).attr(Attribute.Italic));
    }

    /**
     * Label property
     *
     * Returns: The visible label
     */
    pure @property auto label() @safe @nogc nothrow const
    {
        return _label;
    }

    /**
     * Label property
     *
     * Params:
     *      s = New label
     */
    @property void label(string s) @safe
    {
        if (_label == s)
        {
            return;
        }
        _label = s;
        changed = true;
    }

    /**
     * Total property
     *
     * Returns: Total value
     */
    pure @property double total() @safe @nogc nothrow const
    {
        return _total;
    }

    /**
     * Total property
     *
     * Params:
     *      dlTotal = New total
     */
    @property void total(double dlTotal) @safe
    {
        if (_total == dlTotal)
        {
            return;
        }
        _total = dlTotal;
        changed = true;
    }

    /**
     * Current property
     *
     * Returns: Current value
     */
    pure @property double current() @safe @nogc nothrow const
    {
        return _current;
    }

    /**
     * Current property
     *
     * Params:
     *      dlCurrent = New current value
     */
    @property void current(double dlCurrent) @safe
    {
        if (_current == dlCurrent)
        {
            return;
        }
        _current = dlCurrent;
        changed = true;
    }

    /**
     * Special property (different colour)
     *
     * Returns: True if this is a specialised progressbar
     */
    pure @property bool special() @safe @nogc nothrow const
    {
        return _special;
    }

    /**
     * Special property
     *
     * Params:
     *      b = Set to special
     */
    pure @property void special(bool b) @safe @nogc nothrow
    {
        _special = b;
    }

private:

    double _total = 0;
    double _current = 0;
    string _label;
    bool _special;
}
