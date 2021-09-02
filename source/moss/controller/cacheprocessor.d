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

module moss.controller.cacheprocessor;

import moss.context;
import moss.jobs;

/**
 * A CacheAssetJob is sent off, asking the processor to actually perform
 * the caching.
 */
@Job public struct CacheAssetJob
{
    /** Where we find the asset on disk */
    string localPath;
}

/**
 * The CacheProcessor is responsible for taking every caching job and perform
 * the caching sequentially.
 */
package final class CacheProcessor : SystemProcessor
{
    /**
     * Construct a new CacheProcessor on its own thread that will process caching
     * as and when a cache job is available
     */
    this()
    {
        super("cacheProcessor", ProcessorMode.Branched, () => context.jobs.hasJobs());
        context.jobs.registerJobType!CacheAssetJob;
    }

    /**
     * Retrieve a single job
     */
    override void run()
    {
        JobIDComponent jobID;
        CacheAssetJob cacheJob;

        if (!context.jobs.claimJob(jobID, cacheJob))
        {
            status = ProcessorStatus.Available;
            return;
        }

        /* Temporarily busy for this job */
        status = ProcessorStatus.Busy;
        scope (exit)
        {
            status = ProcessorStatus.Available;
        }

        import std.stdio : writeln;

        writeln("Caching asset: ", cacheJob);
        context.jobs.finishJob(jobID.jobID, JobStatus.Completed);
    }

    /**
     * Stop all processing
     */
    override void stop()
    {

    }
}
