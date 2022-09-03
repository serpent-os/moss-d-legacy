/*
 * SPDX-FileCopyrightText: Copyright © 2020-2022 Serpent OS Developers
 *
 * SPDX-License-Identifier: Zlib
 */

/**
 * moss.client.sizing
 *
 * Sane formatting of sizes using 1024-based numbers
 *
 * Authors: Copyright © 2020-2022 Serpent OS Developers
 * License: Zlib
 */

module moss.client.sizing;

import std.algorithm : max, min;
import std.math : floor, log, pow;
import std.string : format;

private static const suffixes = ["B", "KiB", "MiB", "GiB", "TiB"];
private static immutable ulong suffixN = cast(ulong)((cast(long) suffixes.length) - 1);
private static immutable unitSize = log(1024);

/**
 * A FormattedSize encapsulates the suffix and power-reduced
 * bytes to permit pretty printing.
 */
public struct FormattedSize
{
    double numUnits;
    string suffix;

    auto toString() @safe const
    {
        return format!"%.2f%s"(numUnits, suffix);
    }
}

/**
 * Format some input size in real units
 *
 * Params:
 *      inp = Double precision size
 * Returns: String formatted size
 */
FormattedSize formatSize(double inp) @safe
{
    immutable bytes = max(inp, 0);
    immutable power = min(floor((bytes > 0 ? log(bytes) : 0) / unitSize), suffixN);
    return FormattedSize(bytes / pow(1024, power), suffixes[cast(ulong) power]);
}
