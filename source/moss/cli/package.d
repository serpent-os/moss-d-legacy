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

module moss.cli;

public import moss.cli.processor;

alias int function(ref Processor p) exec_helper;

/**
 * Command provides the basic API with which to implement subcommand handling
 * in moss. Each command may have an optional alias to make CLI usage simpler.
 */
struct Command
{
    const string primary; /**< Primary command invocation ("install") */
    const string secondary; /**< Secondary invocation ("it") */
    const string helpText; /**< Help text to display */
    const string blurb; /**< One line description for the command */
    exec_helper exec;

    /**
     * If the command matches, return true..
     */
    pragma(inline, true) pure const bool matches(string cmd) @safe @nogc nothrow
    {
        return primary == cmd || secondary == cmd;
    }
}
