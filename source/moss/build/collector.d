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

module moss.build.collector;

import std.path;
import std.file;

/**
 * A CollectionRule simply defines a pattern to match against (glob style)
 * and a priority with which the pattern will be used.
 *
 * Increased priority numbers lead to the rule running before other rules.
 */
package final struct CollectionRule
{
    /**
     * A glob style pattern to match againt
     */
    string pattern = null;

    /**
     * A target name to incorporate, such as "name-devel"
     */
    string target = null;

    /**
     * Priority used to sort the rules
     */
    int priority = 0;

    pure bool match(const(string) inp) @safe
    {
        return globMatch!(CaseSensitive.yes)(inp, pattern);
    }
}

/**
 * The BuildCollector is responsible for collecting and analysing the
 * contents of the build root, and assigning packages for each given
 * path.
 *
 * By default, all files will end up in the main package unless explicitly
 * overridden by a pattern.
 */
final struct BuildCollector
{

public:

    /**
     * Begin collection on the given root directory, considered to be
     * the "/" root filesystem of the target package.
     */
    final void collect(const(string) rootDir) @system
    {
        import std.algorithm;

        _rootDir = rootDir;

        dirEntries(rootDir, SpanMode.depth, false).each!((ref e) => this.analysePath(e));
    }

    /**
     * Return the root directory for our current operational set
     */
    pragma(inline, true) pure final @property string rootDir() @safe @nogc nothrow
    {
        return _rootDir;
    }

    /**
     * Add a priority based rule to the system which can of course be overridden.
     */
    final void addRule(string pattern, string target, uint priority = 0) @safe
    {
        import std.algorithm;

        /* Sort ahead of time */
        rules ~= CollectionRule(pattern, target, priority);
        rules.sort!((a, b) => a.priority > b.priority);
    }

private:

    /**
     * Analyse a given path and start acting on it
     */
    final void analysePath(ref DirEntry e) @system
    {
        import std.stdio;
        import std.string : format;
        import std.algorithm;
        import std.range;

        auto targetPath = e.name.relativePath(rootDir);

        /* Ensure full "local" path */
        if (targetPath[0] != '/')
        {
            targetPath = "/%s".format(targetPath);
        }

        auto fullPath = e.name;
        /* Find out whre it goes */
        auto matching = rules.filter!((r) => r.match(targetPath)).takeOne().front;
        writefln("%s = %s", fullPath, matching.target);
    }

    string _rootDir = null;
    CollectionRule[] rules;
}
