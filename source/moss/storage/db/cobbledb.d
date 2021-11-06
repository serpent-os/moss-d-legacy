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

module moss.storage.db.cobbledb;

public import moss.deps.query;

/**
 * The CobbleDB provides a temporary source to emulate a repository of local
 * .stone archives as passed from "moss install" CLI to allow full integration
 * of side-loaded stone archives.
 */
public final class CobbleDB : QuerySource
{
    /**
     * Provide matching facilities for the local set of stones
     */
    const(PackageCandidate)[] queryProviders(in MatchType type, in string matcher)
    {
        return [];
    }
}
