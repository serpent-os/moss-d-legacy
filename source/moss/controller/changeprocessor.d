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

import moss.format.binary.reader;
import moss.format.binary.payload.meta;
import moss.storage.db.statedb;

import moss.controller : MossController;
import moss.context;
import moss.jobs;
import std.array : array;
import std.algorithm : each, canFind, remove;
import std.exception : enforce;
import std.string : format;
import std.stdint : uint64_t;

/**
 * Used for state machine purposes, making the ChangeProcessor reentrant on
 * singular jobs
 */
enum ChangeState
{
    /**
     * If our ChangeSet is None, we can retrieve a job.
     */
    None = 0,

    /**
     * Fetching things
     */
    Fetching,

    /**
     * Working things out
     */
    Solving,

    /**
     * Caching those things
     */
    Caching,

    /**
     * Blit the filesystem
     */
    Blit,

    /**
     * Finalise the install
     */
    Finalise,

    /**
     * Failure to work
     */
    Failed,
}
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

    @disable this();

    /**
     * Construct a new ChangeProcessor on the main thread
     */
    this(MossController controller)
    {
        super("changeProcessor", ProcessorMode.Main);
        this.controller = controller;
        context.jobs.registerJobType!ChangeRequest;
    }

    /**
     * Pull new job if we can, otherwise keep working
     */
    override bool allocateWork()
    {
        if (state == ChangeState.None)
        {
            return context.jobs.claimJob(jobID, req);
        }
        return state != ChangeState.None;
    }
    /**
     * All work must be processed safely within syncWork
     */
    override void performWork()
    {
        import std.stdio : writeln;

        if (state != ChangeState.Solving)
        {
            return;
        }

        systemState = controller.stateDB.lastState();
        /* The real state ID will be added in time. */
        targetState = State(controller.stateDB.nextStateID(),
                "Automatically generated state", "%s".format(req));
        controller.stateDB.addState(targetState);

        switch (req.type)
        {
            /* Handle installation of local packages */
        case ChangeType.InstallArchives:

            /* Resolve pkgIDs */
            foreach (p; req.targets)
            {
                resolvedArchiveIDs[p] = resolveArchiveID(p);
            }

            /* Copy all manual */
            const auto oldSelections = controller.stateDB.entries(systemState.id).array;
            oldSelections.each!((sel) => controller.stateDB.markSelection(targetState.id, sel));

            /* Mark them for installation */
            req.targets.each!((p) => {
                auto sel = Selection(resolvedArchiveIDs[p], SelectionReason.ManuallyInstalled);
                controller.stateDB().markSelection(targetState.id, sel);
            }());
            cacheNeeded = req.targets.length;

            break;
            /* Handle removal of local packages */
        case ChangeType.RemovePackages:

            /* Load existing IDs into the DB */
            auto oldSelections = controller.stateDB.entries(systemState.id).array;
            oldSelections.each!((sel) => controller.queryManager.loadID(sel.target));
            controller.queryManager.update();
            string[] removalIDs;

            foreach (removable; req.targets)
            {
                auto candidates = controller.queryManager.byName(removable);
                if (candidates.empty)
                {
                    writeln("Unknown package: ", removable);
                    state = ChangeState.Failed;
                    return;
                }
                auto candidateSet = candidates.array();
                bool didRemove = false;
                foreach (candidate; candidateSet)
                {
                    if (!oldSelections.canFind!((s) => s.target == candidate.id))
                    {
                        continue;
                    }
                    oldSelections = oldSelections.remove!((s) => s.target == candidate.id);
                    didRemove = true;
                    removalIDs ~= candidate.id;
                }
                if (!didRemove)
                {
                    state = ChangeState.Failed;
                    writeln("Package not installed, so cannot be removed: ", removable);
                    return;
                }
            }

            /* Use the trimmed list */
            oldSelections.each!((sel) => controller.stateDB.markSelection(targetState.id, sel));
            writeln("New selections: ", oldSelections);
            writeln("Removing the following packages: ", removalIDs);
            state = ChangeState.Blit;
            break;
        default:
            break;
        }
    }

    override void syncWork()
    {
        import std.stdio : writeln;
        import moss.controller.cacheprocessor : CacheAssetJob;

        switch (state)
        {
        case ChangeState.None:
            writeln("Starting the ChangeSet");
            state = ChangeState.Solving;
            break;
        case ChangeState.Solving:
            writeln("Begin caching");
            state = ChangeState.Caching;
            req.targets.each!((e) => {
                context.jobs.pushJob(CacheAssetJob(e), () => {
                    cachedTotal++;
                    cachedSuccess++;
                }(), () => { cachedTotal++; }());
            }());
            break;
        case ChangeState.Caching:
            /* Break caching when all are cached.. */
            if (cachedTotal == cacheNeeded)
            {
                if (cachedSuccess == cachedTotal)
                {
                    writeln("Caching success");
                    state = ChangeState.Blit;
                }
                else
                {
                    writeln("Caching failure");
                    state = ChangeState.Failed;
                }
            }
            break;
        case ChangeState.Blit:
            writeln("Blitting filesystem");
            state = ChangeState.Finalise;
            emitNewState();
            break;
        case ChangeState.Failed:
            writeln("Complete failure");
            context.jobs.finishJob(jobID.jobID, JobStatus.Failed);
            break;
        case ChangeState.Finalise:
            writeln("Finalising the ChangeSet");
            context.jobs.finishJob(jobID.jobID, JobStatus.Completed);
            state = ChangeState.None;
            applySystemState();
            break;
        default:
            break;
        }
    }

private:

    /**
     * Emit the new /usr tree and such
     */
    void emitNewState()
    {
        controller.rootContructor.construct(targetState);
    }

    /**
     * Update the system pointers atomically
     */
    void applySystemState()
    {
        controller.updateSystemPointer(targetState);
    }

    /**
     * Duplicate of installDB.getPkgID
     */
    string resolveArchiveID(const(string) path)
    {
        auto pkgFile = File(path, "rb");
        auto reader = new Reader(pkgFile);
        auto payload = reader.payload!MetaPayload;

        string pkgName = null;
        uint64_t pkgRelease = 0;
        string pkgVersion = null;
        string pkgArchitecture = null;

        payload.each!((t) => {
            switch (t.tag)
            {
            case RecordTag.Name:
                pkgName = t.val_string;
                break;
            case RecordTag.Release:
                pkgRelease = t.val_u64;
                break;
            case RecordTag.Version:
                pkgVersion = t.val_string;
                break;
            case RecordTag.Architecture:
                pkgArchitecture = t.val_string;
                break;
            default:
                break;
            }
        }());

        enforce(pkgName !is null, "getPkgID(): Missing Name field");
        enforce(pkgVersion !is null, "getPkgID(): Missing Version field");
        enforce(pkgArchitecture !is null, "getPkgID(): Missing Architecture field");

        return "%s-%s-%d.%s".format(pkgName, pkgVersion, pkgRelease, pkgArchitecture);
    }

    JobIDComponent jobID;
    ChangeRequest req;
    ChangeState state = ChangeState.None;
    ulong cacheNeeded = 0;
    ulong cachedTotal = 0;
    ulong cachedSuccess = 0;

    string[string] resolvedArchiveIDs;

    MossController controller;
    State systemState;
    State targetState;
}
