/* SPDX-License-Identifier: Zlib */

/**
 * main
 *
 * Main entry point for moss. Parse cmd-line options and set up logging.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */
module main;

import std.stdio;
import moss.cli;

int main(string[] args)
{
    auto clip = cliProcessor!MossCLI(args);
    auto add = clip.addCommand!AddCommand;
    add.addCommand!AddRepoCommand;
    clip.addCommand!ExtractCommand;
    clip.addCommand!InfoCommand;
    clip.addCommand!InspectCommand;
    clip.addCommand!IndexCommand;
    clip.addCommand!InstallCommand;
    auto ls = clip.addCommand!ListCommand;
    ls.addCommand!ListAvailableCommand;
    ls.addCommand!ListInstalledCommand;
    clip.addCommand!RemoveCommand;
    clip.addCommand!UpdateCommand;
    clip.addCommand!VersionCommand;
    clip.addCommand!HelpCommand;
    return clip.process(args);
}
