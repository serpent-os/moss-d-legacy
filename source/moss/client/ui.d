/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.ui
 *
 * UI abstraction
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.ui;

import core.sys.posix.unistd : isatty, STDOUT_FILENO;
import std.string : format;
import std.meta : staticMap;
import std.traits : EnumMembers, getUDAs;

import std.stdio : stdout;
import std.string : format, join;
import std.range : isInputRange, chunks, empty, ElementType;
import std.algorithm : map, maxElement, each;
import std.conv : to;

import moss.deps.registry.item : RegistryItem;

/**
 * Renderable Text[] for a RegistryItem
 */
auto toTexts(RegistryItem item) @safe
{
    auto info = item.info();
    return [
        Text(info.name).attr(Attribute.Bold), Text(" - "),
        Text(info.versionID).fg(Color.Magenta), Text("-"),
        Text(info.releaseNumber.to!string).fg(Color.Cyan),
    ];
}

/* Map input items into Text representation */
private static struct TextMap
{
    Text[] repr;

    auto toString() @safe
    {
        return repr.map!((r) => r.toString).join("");
    }

    auto @property length() @safe
    {
        ulong val;
        repr.each!((v) => val += v.text.length);
        return val;
    }
}

/**
 * Encapsulate information about the current
 * terminal environment
 */
package struct TerminalInfo
{
    bool supportsColor;
    bool hasPTY;
}

alias ansiValue = uint;

/**
 * Attributes to apply
 */
public enum Attribute : uint
{
    @ansiValue(0) Reset = 1 << 0,
    @ansiValue(1) Bold = 1 << 1,
    @ansiValue(3) Italic = 1 << 2,
    @ansiValue(4) Underline = 1 << 3,
    @ansiValue(5) Blinking = 1 << 4,
    @ansiValue(7) Inverse = 1 << 5,
    @ansiValue(8) Hidden = 1 << 6,
    @ansiValue(9) Strikethrough = 1 << 7
}

/**
 * Color (+10 for background)
 */
public enum Color : uint
{
    @ansiValue(30) Black = 0,
    @ansiValue(31) Red,
    @ansiValue(32) Green,
    @ansiValue(33) Yellow,
    @ansiValue(34) Blue,
    @ansiValue(35) Magenta,
    @ansiValue(36) Cyan,
    @ansiValue(37) White,
    @ansiValue(39) Default,
    @ansiValue(0) Reset,
}

public struct Text
{
    string text;

    /**
     * Set the foreground color
     */
    ref @property Text fg(Color c) return @safe
    {
        this._fg = c;
        return this;
    }

    ref @property Text bg(Color c) return @safe
    {
        this._bg = c;
        return this;
    }

    ref @property Text attr(Attribute attributes) return @safe
    {
        this.attributes = attributes;
        return this;
    }

    /**
     * Render this text for the console
     */
    pure auto toString() @safe const
    {
        uint bgZ;
        uint fgZ;
        uint at = 0;

        static foreach (member; EnumMembers!Color)
        {
            if (member == _fg)
            {
                fgZ = getUDAs!(member, ansiValue)[0];
            }
            else if (member == _bg)
            {
                bgZ = getUDAs!(member, ansiValue)[0] + 10;
            }
        }

        static foreach (member; EnumMembers!Attribute)
        {
            if (attributes == member)
            {
                at = getUDAs!(member, ansiValue)[0];
            }
        }
        /* No bg color */
        if (_bg == Color.Default)
        {
            /* no fg color */
            if (_fg == Color.Default)
            {
                /* No attribute.. */
                if (attributes == Attribute.init)
                {
                    return format!"\x1B[0;m%s\x1B[0;m"(text);
                }
                return format!"\x1B[0;m\x1B[%dm%s\x1B[0;m"(at, text);
            }
            return format!"\x1B[0;m\x1B[%d;%dm%s\x1B[0;m"(at, fgZ, text);
        }

        return format!"\x1B[0;m\x1B[%d;%d;%dm%s\x1B[0;m"(at, bgZ, fgZ, text);
    }

private:

    Color _fg = Color.Default;
    Color _bg = Color.Default;
    Attribute attributes;
}

/**
 * Convert Color into an ANSI foreground color
 */
public template fgColor(Color c)
{
    import std.conv : to;

    static foreach (member; EnumMembers!Color)
    {
        static if (member == c)
        {
            enum ansi = getUDAs!(member, ansiValue)[0];
            char[] fgColor = "\x1B[1;" ~ (cast(char[])(ansi.to!string)) ~ "m";
        }
    }
}
/**
 * Convert Color into an ANSI background color
 */
public template bgColor(Color c)
{
    import std.conv : to;

    static foreach (member; EnumMembers!Color)
    {
        static if (member == c)
        {
            enum ansi = getUDAs!(member, ansiValue)[0] + 10;
            char[] fgColor = "\x1B[1;" ~ (cast(char[])(ansi.to!string)) ~ "m";
        }
    }
}

/**
 * Our textual "user interface"
 */
public final class UserInterface
{
    /**
     * Construct a new UserInterface
     */
    this() @safe
    {
        initTinfo();
    }

    /**
     * Handle inform forward
     *
     * Params:
     *      message = Message to print
     */
    void inform(string message) @safe
    {
        inform!"%s"(message);
    }

    /**
     * Inform the user of something happening
     *
     * Params:
     *      fmt = Format string
     *      p = Parameters
     */
    void inform(string fmt, S...)(S p) @trusted
    {
        immutable portion = format!fmt(p);
        stdout.writefln!" ⦁ %s"(portion);
    }

    /**
     * Warn the user
     *
     * Params:
     *      message = Message to print
     */
    void warn(string message) @safe
    {
        warn!"%s"(message);
    }

    /**
     * Warn the user
     *
     * Params:
     *      fmt = Format string
     *      p = Parameters
     */
    void warn(string fmt, S...)(S p) @trusted
    {
        immutable portion = format!fmt(p);
        stdout.writefln!" %s  %s"(Text("⚠").fg(Color.Yellow), portion);
    }

    /**
    * Emit the given things as column separated
    */
    void emitAsColumns(R)(R items) @trusted const if (isInputRange!R)
    {
        static int columnsLimit = 80;
        import std.array : array;
        import std.algorithm : sort;

        if (items.empty)
        {
            return;
        }

        auto displayable = items.map!((i) => TextMap(toTexts(i)));
        /* Auto pad. */
        auto largestWidth = (displayable.maxElement!"a.length".length) + 4;

        auto nColumns = columnsLimit / largestWidth;
        auto workset = displayable.array;
        workset.sort!"a.toString < b.toString";

        foreach (set; workset.chunks(nColumns))
        {
            foreach (elem; set)
            {
                stdout.writef!"%s%*s"(elem, largestWidth - elem.length, " ");
            }
            stdout.writeln();
        }
    }

private:

    /**
     * Initialise knowledge of the TerminalInfo
     */
    void initTinfo() @trusted
    {
        immutable hasTTY = isatty(STDOUT_FILENO) == 0;
        tinfo.supportsColor = hasTTY;
        tinfo.hasPTY = hasTTY;
    }

    TerminalInfo tinfo;
}
