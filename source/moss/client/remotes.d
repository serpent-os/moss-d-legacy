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
import std.path : dirName, baseName;
import std.file : mkdirRecurse;
import std.experimental.logger;
public import moss.core.errors;
import moss.core.fetchcontext;

alias RemoteResult = Optional!(Success, Failure);

/**
 * Manage various system remotes - whether they're source or binary.
 */
public final class RemoteManager
{

    /**
     * Initialise the RemoteManager with the given Installation
     */
    this(FetchContext fetch, Installation install) @safe
    {
        this.installation = install;
        this.fetch = fetch;
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

    /**
     * Add a new remote
     *
     * Params:
     *      identifier = Unique identifier for the remote
     *      origin = Where to download things from.
     * Returns: A RemoteResult
     */
    RemoteResult add(string identifier, string origin) @safe
    {
        import std.file : write;

        /**
         * Mutable only!
         */
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

        return refresh();
    }

    /**
     * Refresh all of the remotes
     *
     * Returns: RemoteResult
     */
    RemoteResult refresh() @safe
    {
        reloadConfiguration();
        foreach (ref rm; remotes)
        {
            auto destPath = installation.joinPath(".moss", "remotes", rm.id, rm.uri.baseName);
            destPath.dirName.mkdirRecurse();
            auto fetchable = Fetchable(rm.uri, destPath, 0, FetchType.RegularFile, null);
            info(fetchable);
            fetch.enqueue(fetchable);
        }

        /**
         * Fetch all of our fetchables
         */
        while (!fetch.empty)
        {
            fetch.fetch();
        }

        return cast(RemoteResult) fail("Not yet implemented");
    }

private:

    Repository[] remotes;
    Installation installation;
    FetchContext fetch;
}
