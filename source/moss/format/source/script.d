/*
 * This file is part of moss.
 *
 * Copyright © 2020 Serpent OS Developers
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

module moss.format.source.script;

import std.string : format, splitLines, startsWith, endsWith;
import std.exception : enforce;
import moss.format.source.macros : MacroFile;
import std.string : strip;

/**
 * The private ParseContext is used by the Script to step through
 * scripts and replace macros with their equivalent data.
 */
static struct ParseContext
{
    ulong macroStart;
    ulong macroEnd;
    ulong braceStart;
    ulong braceEnd;

    bool inMacro = false;
    bool hasMacro = false;

    /**
     * Reset the current context completely.
     */
    void reset() @safe @nogc nothrow
    {
        inMacro = false;
        macroStart = 0;
        macroEnd = 0;
        braceStart = 0;
        braceEnd = 0;
        hasMacro = false;
    }
}

/**
 * A ScriptBuilder must be populated for the current build context
 * completely, which means all current source information should be
 * present before baking.
 *
 * The ScriptBuilder must also be populated with system macros before
 * it is in any way usable, otherwise macro expansion is not possible.
 *
 * Once fully populated, a ScriptBuilder can replace (recursively) all
 * instances of macros + variables with their correct text, allowing
 * smart build scripts to be created.
 *
 * Each build *type* should have a ScriptBuilder baked for it, i.e.
 * for each architecture and profile.
 */
struct ScriptBuilder
{

public:

    /**
     * Add an action to the builder by its ID.
     *
     * An action starts with the % character, and is deemed an actionable
     * task, such as %configure. The text is replaced with the action
     * text and will be recursively resolved.
     */
    void addAction(string id, string action) @safe
    {
        enforce(!baked, "Cannot addAction to baked ScriptSubstituter");
        mapping["%s%s".format(macroStart, id)] = action.strip();
    }

    /**
     * Add a defintition to the builder by its ID
     *
     * A definition is enclosed in `%(` and `)`. It provides a variable
     * that is available at "compile time", rather than run time.
     */
    void addDefinition(string id, string define) @safe
    {
        enforce(!baked, "Cannot addDefinition to baked ScriptSubstituter");
        mapping["%s%s%s".format(defineStart, id, defineEnd)] = define.strip();
    }

    /**
     * Add an export to the builder by its ID.
     *
     * An export is provided for runtime, and is mapped to a pre-baked
     * value from addDefinition.
     *
     * This allows manipulating certain macros at runtime with the shell.
     */
    void addExport(string id, string altName = null) @safe
    {
        enforce(baked, "Cannot addExport to unbaked ScriptSubstituter");
        auto realID = "%s%s%s".format(defineStart, id, defineEnd);
        enforce(realID in mapping, "addExport: Unknown macro: " ~ realID);
        if (altName !is null)
        {
            exports[altName.strip()] = mapping[realID.strip()];
        }
        else
        {
            exports[id.strip()] = mapping[realID.strip()];
        }
    }

    /**
     * Insert definitions, exports + actions from a macro file.
     */
    final void addFrom(in MacroFile* f) @system
    {
        /* Add all definitions */
        foreach (ref k, v; f.definitions)
        {
            addDefinition(k, v);
        }

        /* Add all actions */
        foreach (ref k, v; f.actions)
        {
            addAction(k, v);
        }
    }

    /**
     * Recursively evaluate every action + definition until they
     * are completely processed and validated.
     *
     * This vastly simplifies substitution in the next set of script
     * evaluation.
     */
    void bake() @safe
    {
        if (baked)
        {
            return;
        }
        foreach (ref k, v; mapping)
        {
            mapping[k] = process(v).strip();
        }
        baked = true;
    }

    /**
     * Begin tokenisation of the file, line by line
     */
    string process(const(string) input) @safe
    {
        auto context = ParseContext();
        string lastLine;
        char lastChar = '\0';
        string ret = "";

        if (input.length < 3)
        {
            return input;
        }

        void handleMacro()
        {
            if (!context.hasMacro)
            {
                return;
            }

            if (context.braceStart > 0)
            {
                enforce(context.braceEnd > context.braceStart, "Must end variable with: )");
            }

            if (context.macroStart >= context.macroEnd)
            {
                return;
            }
            if (context.macroEnd >= input.length)
            {
                return;
            }

            string macroName = lastLine[context.macroStart .. context.macroEnd + 1];
            enforce(macroName in mapping, "Unknown macro: " ~ macroName);

            /* Store used actions */
            if (baked && context.braceEnd < 1)
            {
                usedMacros ~= macroName;
            }

            auto newval = process(mapping[macroName]);
            ret ~= newval;
            context.reset();
        }

        auto lines = input.splitLines();

        foreach (const ref line; lines)
        {
            lastLine = line;
            size_t len = line.length;
            foreach (size_t i, const char c; line)
            {
                switch (c)
                {
                case '%':
                    context.inMacro = !context.inMacro;
                    if (i <= len && line[i + 1] == '%')
                    {
                        ret ~= "%";
                        context.reset();
                        break;
                    }
                    if (lastChar == '%')
                    {
                        ret ~= "%";
                        context.inMacro = false;
                        context.reset();
                        break;
                    }
                    if (context.inMacro)
                    {
                        context.macroStart = i;
                    }
                    else
                    {
                        context.macroEnd = i;
                    }
                    break;
                case '(':
                    if (context.inMacro)
                    {
                        context.braceStart = i;
                    }
                    else
                    {
                        context.reset();
                        ret ~= c;
                    }
                    break;
                case ')':
                    if (context.inMacro)
                    {
                        context.braceEnd = i;
                        context.macroEnd = i;
                        context.hasMacro = true;
                        handleMacro();
                    }
                    else
                    {
                        context.reset();
                        ret ~= c;
                    }
                    break;
                default:
                    if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_')
                    {
                        if (context.inMacro)
                        {
                            context.hasMacro = true;
                            context.macroEnd = i;
                        }
                        else
                        {
                            ret ~= c;
                        }
                        break;
                    }
                    else
                    {
                        if (context.hasMacro)
                        {
                            handleMacro();
                        }
                        ret ~= c;
                        context.reset();
                    }
                    break;
                }
                lastChar = c;
            }
            if (context.hasMacro)
            {
                handleMacro();
            }
            context.reset();
            if (lines.length > 1)
            {
                ret ~= "\n";
            }
        }
        if (ret.endsWith('\n'))
        {
            ret = ret[0 .. $ - 1];
        }
        return ret;
    }

private:

    char macroStart = '%';

    string defineStart = "%(";
    string defineEnd = ")";
    string commentStart = "#";

    string[string] mapping;
    string[string] exports;
    bool baked = false;
    string[] usedMacros;
}
