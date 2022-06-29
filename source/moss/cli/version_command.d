/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.cli.version_command
 *
 * Display version of moss and associated libraries.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.cli.version_command;

public import moss.core.cli;
import moss.core;

/**
 * The VersionCommand provides a CLI system to emit the
 * versioning information for moss and associated libraries
 */
@CommandName("version")
@CommandHelp("Show the program version and exit")
public struct VersionCommand
{
    /** Extend BaseCommand with VersionCommand utility */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the VersionCommand
     */
    @CommandEntry() int run(ref string[] argv)
    {
        import std.stdio : writeln, writefln;

        writefln!"moss, version %s"(moss.core.Version);
        writeln("\nCopyright © 2020-2022 Serpent OS Developers");
        writeln("Available under the terms of the Zlib license");
        return ExitStatus.Success;
    }
}
