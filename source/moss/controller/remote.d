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

module moss.controller.remote;

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

        repoConfig = new Configuration!(Repository[]);
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

private:

    /**
     * Reload the on-disk configuration
     *
     * TODO: Some kind of useful error handling and logging
     */
    void reload()
    {
        repoConfig = new Configuration!(Repository[]);
        repoConfig.load(context.paths.root);

    }

    Configuration!(Repository[]) repoConfig;
    RepoPlugin[] _plugins;
    CachePool _pool = null;
}
