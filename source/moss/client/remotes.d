/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.remotes
 *
 * Remote Management API
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.remotes;

public import moss.config.repo;
public import moss.client.installation;

import std.uni : isAlphaNum, toLower;
import std.algorithm : map;
import std.conv : to;
import std.string : format;
import std.path : dirName;
import std.file : mkdirRecurse;
import std.experimental.logger;
public import moss.core.errors;

alias RemoteResult = Optional!(Success, Failure);

/**
 * Manage various system remotes - whether they're source or binary.
 */
public final class RemoteManager
{

    /**
     * Initialise the RemoteManager with the given Installation
     */
    this(Installation install) @safe
    {
        this.installation = install;
        reloadConfiguration();
    }

    /**
     * Reload the configuration
     */
    void reloadConfiguration() @safe
    {
        auto config = new RepositoryConfiguration();
        () @trusted { config.load(installation.root); }();
        remotes = config.sections;
    }

    /**
     * Active configuration
     */
    pure auto @property active() @safe @nogc nothrow const
    {
        return remotes;
    }

    /** API METHODS */
    RemoteResult add(string identifier, string origin) @safe
    {
        import std.file : write;

        if (installation.mutability != Mutability.ReadWrite)
        {
            return cast(RemoteResult) fail("Cannot add remote to non-mutable system");
        }

        immutable saneID = identifier.map!((m) => (m.isAlphaNum ? m : '_').toLower)
            .to!string;
        immutable confFile = installation.joinPath("etc", "moss", "repos.conf.d", saneID ~ ".conf");
        immutable description = "User added repository";
        immutable data = format!`
- %s:
    description: "%s"
    uri: "%s"
`(saneID, description, origin);
        tracef("New config at: %s", confFile);

        confFile.dirName.mkdirRecurse();

        write(confFile, data);

        return cast(RemoteResult) Success();
    }

private:

    Repository[] remotes;
    Installation installation;
}
