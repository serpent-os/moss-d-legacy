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

module main;

import std.stdio;
import moss.cli;

int main(string[] args)
{
    auto clip = cliProcessor!MossCLI(args);
    clip.addCommand!ExtractCommand;
    clip.addCommand!InfoCommand;
    clip.addCommand!InspectCommand;
    clip.addCommand!IndexCommand;
    clip.addCommand!InstallCommand;
    auto ls = clip.addCommand!ListCommand;
    ls.addCommand!ListAvailableCommand;
    ls.addCommand!ListInstalledCommand;
    clip.addCommand!RemoveCommand;
    clip.addCommand!VersionCommand;
    clip.addCommand!HelpCommand;
    return clip.process(args);
}
