/*
 * This file is part of moss.
 *
 * Copyright © 2020-2021 Serpent OS Developers
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

module moss.cli.install_command;

public import moss.core.cli;
import moss.core;
import moss.manager;
import moss.cli : MossCLI;

/**
 * The InstallCommand provides a CLI system to install a package, whether from
 * a local file or a repository.
 */
@CommandName("install")
@CommandHelp("Install a local package")
public struct InstallCommand
{
    /** Extend BaseCommand with install utility */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the InstallCommand
     */
    @CommandEntry() int run(ref string[] argv)
    {
        import std.stdio : writeln, stderr;
        import std.algorithm : each, uniq;

        /* Create appropriate Manager object */
        auto base = pt.findAncestor!MossCLI;
        auto manager = new StateManager(base.rootDirectory !is null ? base.rootDirectory : "/");

        /* Begin construction of a new state */
        auto state = manager.currentState;
        auto transaction = state.beginTransaction();

        /* For now, we only support local archive installs. */
        argv.uniq.each!((p) => transaction.installLocalArchive(p));

        writeln(transaction);

        /* Condense and apply */
        auto newStates = transaction.end();
        writeln(newStates);
        manager.apply(newStates[0]);
        return ExitStatus.Failure;
    }
}
