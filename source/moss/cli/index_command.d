/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.cli.index_command
 *
 * Generate a moss repository index for a set of .stone packages.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.cli.index_command;

public import moss.core.cli;

import moss.core;
import moss.format.binary.repo;
import moss.context;
import std.stdio;
import std.file : exists, dirEntries, SpanMode;
import std.string : endsWith;
import std.path : relativePath, absolutePath;

/**
 * Generate repository index for all encountered packages
 */
@CommandName("index")
@CommandHelp("Generate basic repository index")
public struct IndexCommand
{
    /** Extend BaseCommand to provide indexing capability */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the IndexCommand
     */
    @CommandEntry() int run(ref string[] argv)
    {
        auto workDir = ".";
        if (argv.length > 0)
        {
            workDir = argv[0];
        }

        if (!workDir.exists)
        {
            stderr.writefln!"Indexing directory '%s' does not exist!"(workDir);
        }

        workDir = workDir.absolutePath;

        /* Either emit to current directory, or the output directory. */
        auto writer = new RepoWriter(context.paths.root == "/" ? "." : context.paths.root);
        scope (exit)
        {
            writer.close();
        }

        /* Walk to find each .stone file */
        foreach (string path; dirEntries(workDir, SpanMode.shallow))
        {
            if (!path.endsWith(".stone"))
            {
                continue;
            }
            writefln!"Indexing: %s"(path);
            writer.addPackage(path, path.relativePath(workDir));
        }
        return ExitStatus.Failure;
    }
}
