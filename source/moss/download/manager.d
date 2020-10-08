/*
 * This file is part of moss.
 *
 * Copyright © 2020 Serpent OS Developers
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

module moss.download.manager;

public import moss.download.cache;

/**
 * A Download is an as-yet-unimplemented type that will
 * be used for download tracking
 */
final struct Download
{
    /** Where to find the file */
    string uri;

    /* Expected hash when downloaded */
    string expectedHash;
}

/**
 * A DownloadManager is responsible for downloading files from the network
 * to disk, and storing them in a DownloadStore. Once verified, files are
 * permitted for use.
 *
 * Additionally a DownloadManager may make use of multiple caches in order
 * to permit cache sharing, i.e. bind-mounted host downloads into a guest
 * instance of moss.
 */
final class DownloadManager
{

public:

    /**
     * Add a cache to our list of known caches
     *
     * System caches are always checked first
     */
    final void add(DownloadStore c) @safe
    {
        import std.algorithm.sorting;

        stores ~= c;

        /* Sort: System first */
        sort!((a, b) => a.type > b.type)(stores);
    }

    /**
     * Add a download to the queue
     */
    final void add(ref Download d) @safe
    {
        toDownload ~= d;
    }

    /**
     * Return true if we have the file in our caches
     */
    final bool contains(const(string) hash) @safe nothrow
    {
        foreach (ref st; stores)
        {
            if (st.contains(hash))
            {
                return true;
            }
        }
        return false;
    }

private:

    DownloadStore[] stores;
    Download[] toDownload;
}
