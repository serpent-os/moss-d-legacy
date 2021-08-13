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

module moss.query.source;

public import moss.query.candidate;

/**
 * QueryResult can be successful (found) and set, or empty and false
 */
public struct QueryResult
{
    /**
     * Candidate to return if the query was successfully found
     */
    PackageCandidate candidate;

    /**
     * Set to true if we find the candidate
     */
    bool found = false;
}
/**
 * A QuerySource is added to the QueryManager allowing it to load data from pkgIDs
 * if present.
 */
public interface QuerySource
{

    /**
     * Attempt to return a PackageCandidate for the given ID.
     * It is illegal for any source to contain more than one candidate for a given
     * ID as they should be keyed by ID internally.
     */
    QueryResult queryID(const(string) pkgID);
}
