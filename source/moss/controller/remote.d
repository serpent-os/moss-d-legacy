/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.controller.remote
 *
 * Manage moss index repositories (which can be both local and remote).
 *
 * In package.d files containing only imports and nothing else,
 * 'Module namespace imports.' is sufficient description.
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.controller.remote;

import moss.core.fetchcontext;
import moss.context;
import moss.config.io;
import moss.config.repo;
import moss.controller.plugins.repo;

import std.exception : enforce;
import std.range : empty;
import std.string : format;

public import moss.storage.cachepool;

/**
 * In moss terms (internally) a remote is essentially a repository but we're only
 * clients to those endpoints.
 *
 * This class is responsible for managing the stored end points and syncing that
 * with the on-disk configuration.
 */
public final class RemoteManager
{

    @disable this();

    /**
     * Construct a new RemoteManager which will reload the configuration on
     * initialisation
     */
    this(CachePool pool)
    {
        assert(pool !is null);
        _pool = pool;

        repoConfig = new RepositoryConfiguration();
        repoConfig.load(context.paths.root);

        foreach (section; repoConfig.sections)
        {
            const auto uri = section.uri;
            const auto description = section.description;
            const auto id = section.id;

            enforce(uri !is null && !uri.empty, format!"%s: URI cannot be empty"(id));
            enforce(description !is null && !description.empty,
                    format!"%s: Description cannot be empty"(id));
            auto plugin = new RepoPlugin(pool, id, uri);
            _plugins ~= plugin;
        }
    }

    /**
     * Return our managed plugins
     */
    pure auto @property plugins() @safe @nogc nothrow
    {
        return _plugins;
    }

    /**
     * For all owned remotes, request they forcibly update.
     */
    void updateRemotes(FetchContext context)
    {
        foreach (remote; plugins)
        {
            remote.update(context);
        }
    }

private:

    RepositoryConfiguration repoConfig;
    RepoPlugin[] _plugins;
    CachePool _pool = null;
}
