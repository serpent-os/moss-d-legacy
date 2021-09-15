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

module moss.controller.changeprocessor;

import moss.context;
import moss.jobs;

/**
 * A ChangeType accompanies each ChangeRequest so we know what the user wants
 * us to do with the targets.
 */
public enum ChangeType
{
    /**
     * Install local archives
     */
    InstallArchives = 0,
    /* InstallPackages, */

    /**
     * Remove packages by name
     */
    RemovePackages,
}

/**
 * A ChangeRequest is sent to the ChangeProcessor to begin the mutation of
 * a base state into a new state.
 */
@Job public struct ChangeRequest
{
    /**
     * Type of change requested
     */
    ChangeType type;

    /**
     * Targets to operate on, i.e. list of names
     */
    string[] targets;
}

/**
 * The ChangeProcessor is responsible for accepting incoming change requests,
 * working on them sequentially and sending off the appropriate jobs.
 */
package final class ChangeProcessor : SystemProcessor
{
    /**
     * Construct a new ChangeProcessor on the main thread
     */
    this()
    {
        super("changeProcessor", ProcessorMode.Main);
        context.jobs.registerJobType!ChangeRequest;
    }

    override bool allocateWork()
    {
        return context.jobs.claimJob(jobID, req);
    }
    /**
     * Retrieve a single job
     */
    override void performWork()
    {
        import std.stdio : writeln;

        writeln("Processing change: ", req);
    }

    override void syncWork()
    {
        import std.stdio : writeln;

        writeln("Syncing change: CHANGEPROCESSOR");
        import moss.controller.cacheprocessor : CacheAssetJob;

        foreach (j; req.targets)
        {
            context.jobs.pushJob(CacheAssetJob(j.dup));
        }

        context.jobs.finishJob(jobID.jobID, JobStatus.Completed);
    }

private:
    JobIDComponent jobID;
    ChangeRequest req;
}
