/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.renderer
 *
 * Line-based console rendering
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.renderer;

import std.algorithm : filter, each;
import std.range : enumerate;
import std.stdio : stdout;

/** 
 * Basic Renderable type
 */
public abstract class Renderable
{
    /**
     * Return the renderable string
     */
    abstract string render() @safe;

    /**
     * Has the display changed?
     */
    pure final @property bool changed() @safe @nogc nothrow const
    {
        return _changed;
    }

    /**
     * Update the changed property
     */
    pure final @property void changed(bool b) @safe @nogc nothrow
    {
        _changed = b;
    }

private:

    bool _changed = true;
}

/**
 * A Renderer is a simple container system containing multiple
 * Renderables. Explicitly this is a vertical layout system with
 * an approach of revisiting *changed* nodes to update them and
 * minimise update noise.
 *
 * Noticably it adds no nesting as we don't want a complex render
 * tree.
 */
public final class Renderer
{

    /**
     * Add a child to the display set
     */
    void add(Renderable child) @trusted
    {
        children ~= child;
        stdout.writeln();
        lastPosition += 1;
    }

    /**
     * Remove a child from the display set
     */
    void remove(Renderable child) @trusted
    {
        import std.algorithm : remove;

        children = children.remove!((c) => c == child);
    }

    /**
     * Draw all contained renderable children
     */
    void draw() @safe
    {
        synchronized (this)
        {
            foreach (index, child; children.enumerate.filter!((t) => t.value.changed))
            {
                drawChild(cast(int) index, child);
            }
        }
    }

    void redraw() @safe
    {
        children.each!((c) => c.changed = true);
        draw();
    }

private:

    /**
     * Draw a single child element that has changed
     *
     * Params:
     *      r = Child element
     */
    void drawChild(int index, Renderable r) @trusted
    {
        scope (exit)
        {
            lastPosition = index;
            r.changed = false;
        }
        if (index > lastPosition)
        {
            /* +ve */
            auto diff = index - lastPosition;
            stdout.writef!"\x1B[%sB"(diff);
        }
        else if (index == lastPosition)
        {
        }
        else
        {
            /* -ve */
            auto diff = lastPosition - index;
            stdout.writef!"\x1B[%sA"(diff);
        }
        stdout.flush();
        /* Clear the line */
        stdout.write("\x1B[2K");
        stdout.flush();
        /* Rewind line, draw again */
        stdout.writef!"\r%s"(r.render());
        stdout.flush();

    }

    Renderable[] children;
    int lastPosition;
}
