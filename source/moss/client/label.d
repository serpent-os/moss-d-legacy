/*
 * SPDX-FileCopyrightText: Copyright © 2020-2023 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.label
 *
 * Console-based label
 *
 * Authors: Copyright © 2020-2023 Serpent OS Developers
 * License: Zlib
 */

module moss.client.label;

public import moss.client.renderer;
public import moss.client.ui : Text, Attribute, Color;

/**
 * Very simple UI label wrapping a Text() struct
 */
public final class Label : Renderable
{
    this() @safe
    {

    }

    /**
     * Construct a new Label with the given Text
     */
    this(Text s) @safe
    {
        label = s;
    }

    /**
     * Render the label
     */
    override string render() @safe
    {
        return " " ~ _label.toString;
    }

    /**
     * Label property
     *
     * Params:
     *      s = New text
     */
    pure @property void label(Text s) @safe
    {
        if (s == _label)
        {
            return;
        }
        _label = s;
        changed = true;
    }

    /**
     * Label property
     *
     * Returns: Label Text()
     */
    pure @property auto label() @safe @nogc nothrow const
    {
        return _label;
    }

private:

    Text _label;
}
