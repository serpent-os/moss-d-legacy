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
import moss.format.source.tuningFlag;
import moss.format.source.tuningGroup;
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
     * Add a TuningFlag to the set
     */
    void addFlag(string name, TuningFlag flag) @safe
    {
        flags[name] = flag;
    }

    /**
     * Add a TuningGroup to the set
     */
    void addGroup(string name, TuningGroup group) @safe
    {
        groups[name] = group;
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

        /* Add all tuning flags */
        foreach (ref k, v; f.flags)
        {
            addFlag(k, v);
        }

        /* Add all tuning groups */
        foreach (ref k, v; f.groups)
        {
            addGroup(k, cast(TuningGroup) v);
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
     * Enable a specific tuning group
     */
    final void enableGroup(string name, string value = null) @safe
    {
        import std.string : format;
        import std.algorithm;

        enforce(name in groups, "enableGroup(): Unknown group: %s".format(name));

        if (!enabledGroups.canFind(name))
        {
            enabledGroups ~= name;
        }

        disabledGroups = disabledGroups.remove!((a) => a == name);

        /* Fallback to default value */
        auto group = groups[name];
        if (value is null)
        {
            value = group.defaultChoice;
        }

        /* Validate value is permitted */
        if (value !is null)
        {
            enforce(group.choices !is null && group.choices.length > 0,
                    "enableGroup(): Non-value option %s".format(name));
            enforce(value in group.choices,
                    "enableGroup(): Unknown value '%s' for '%s'".format(name, value));
            optionSets[name] = value;
        }
    }

    /**
     * Disable a specific tuning group
     */
    final void disableGroup(string name) @safe
    {
        import std.string : format;
        import std.algorithm;

        enforce(name in groups, "disableGroup(): Unknown group: %s".format(name));

        if (!disabledGroups.canFind(name))
        {
            disabledGroups ~= name;
        }

        enabledGroups = enabledGroups.remove!((a) => a == name);

        if (name in optionSets)
        {
            optionSets.remove(name);
        }
    }

    /**
     * Build the final TuningFlag set
     */
    final TuningFlag[] buildFlags() @safe
    {
        import std.algorithm;
        import std.array;
        import std.range;

        string[] enabledFlags = [];
        string[] disabledFlags = [];

        /* Build sets of enablings */
        foreach (enabled; enabledGroups)
        {
            TuningGroup group = groups[enabled];
            TuningOption to = group.root;

            if (enabled in optionSets)
            {
                to = group.choices[optionSets[enabled]];
            }

            if (to.onEnabled !is null)
            {
                enabledFlags ~= to.onEnabled.filter!((e) => !enabledFlags.canFind(e)).array;
            }
        }

        /* Build sets of disablings */
        foreach (disabled; disabledGroups)
        {
            TuningGroup group = groups[disabled];
            if (group.root.onDisabled !is null)
            {
                disabledFlags ~= group.root.onDisabled.filter!((e) => !disabledFlags.canFind(e))
                    .array;
            }
        }

        /* Ensure all flags are known and valid */
        enabledFlags.chain(disabledFlags).each!((e) => enforce(e in flags,
                "buildFlags: Unknown flag: '%s'".format(e)));

        return enabledFlags.chain(disabledFlags).uniq.map!((n) => flags[n]).array;
    }

    /**
     * Begin tokenisation of the file, line by line
     */
    string process(const(string) input) @safe
    {
        auto context = ParseContext();
        import std.string : format;

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

            /* Grab macro now */
            string macroName = lastLine[context.macroStart .. context.macroEnd + 1];

            enforce(!macroName.endsWith("%"),
                    "Legacy style macro unsupported: %s".format(macroName));
            enforce(macroName in mapping, "Unknown macro: %s".format(macroName));

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
                    if (i < len && i + 1 < len && line[i + 1] == '%')
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
                    if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
                            || c == '_' || (c >= '0' && c <= '9'))
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
    TuningFlag[string] flags;
    TuningGroup[string] groups;

    string[] enabledGroups = [];
    string[] disabledGroups = [];
    string[string] optionSets;

    bool baked = false;
    string[] usedMacros;
}
