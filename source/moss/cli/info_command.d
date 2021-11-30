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

module moss.cli.info_command;

public import moss.core.cli;
import moss.core;
import moss.cli : MossCLI;
import moss.context;
import moss.controller;
import std.stdio : stderr;
import moss.deps.dependency;
import moss.deps.registry.item;
import std.string : join, endsWith, format;
import std.file : exists;
import std.algorithm : map;
import std.conv : to;
import std.array : array;

/**
 * InfoCommand is used to display info on local + remote pkgs
 */
@CommandName("info")
@CommandHelp("Display details on a package",
        "Used with either local .stone files or packages known to moss,
this command displays information about the metadata and dependencies.")
@CommandUsage("[.stone file] [package name]")
public struct InfoCommand
{
    /** Extend BaseCommand with Info utility */
    BaseCommand pt;
    alias pt this;

    /**
     * Main entry point into the InfoCommand
    */
    @CommandEntry() int run(ref string[] argv)
    {
        context.setRootDirectory((pt.findAncestor!MossCLI).rootDirectory);

        auto con = new MossController();
        scope (exit)
        {
            con.close();
        }

        if (argv.length < 1)
        {
            stderr.writeln("Requires an argument");
            return ExitStatus.Failure;
        }

        RegistryItem[] lookups;

        foreach (pkg; argv)
        {
            /* Sideloadable */
            if (pkg.endsWith(".stone") && pkg.exists)
            {
                lookups ~= con.loadLocalPackage(pkg);
                continue;
            }

            auto candidates = con.registryManager.byProvider(ProviderType.PackageName, pkg);
            if (candidates.empty)
            {
                stderr.writeln("Unknown package: ", pkg);
                continue;
            }
            lookups ~= candidates.array;
        }

        foreach (l; lookups)
        {
            printInfo(l);
        }

        return ExitStatus.Success;
    }

    public void printInfo(ref RegistryItem item)
    {
        import std.stdio : writefln, writeln;
        import std.range : padLeft;

        static void printAligned(in string key, in string value)
        {
            writefln("%-*s: %s", 14, key, value);
        }

        auto info = item.info;
        printAligned("Name", info.name);
        printAligned("Version", format!"%s, Release %d"(info.versionID, info.releaseNumber));
        printAligned("Summary", info.summary);
        printAligned("Description", info.description);
        printAligned("Homepage", info.homepage);

        foreach (i; 0 .. info.licenses.length)
        {
            if (i == 0)
            {
                printAligned("License", info.licenses[i]);
            }
            else
            {
                auto license = info.licenses[i];
                auto padsize = license.length + 16;
                writeln(license.padLeft(' ', padsize));
            }
        }

        /* Dump dependencies */
        auto deps = item.dependencies();
        foreach (i; 0 .. deps.length)
        {
            if (i == 0)
            {
                printAligned("Dependencies", deps[i].to!string);
            }
            else
            {
                auto depNom = deps[i].to!string();
                auto padsize = depNom.length + 16;
                writeln(depNom.padLeft(' ', padsize));
            }
        }

        /* Dump providers */
        auto provs = item.providers();
        foreach (i; 0 .. provs.length)
        {
            if (i == 0)
            {
                printAligned("Providers", provs[i].to!string);
            }
            else
            {
                auto provNom = provs[i].to!string;
                auto padsize = provNom.length + 16;
                writeln(provNom.padLeft(' ', padsize));
            }
        }
    }
}
