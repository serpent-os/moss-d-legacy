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

module moss;

import core.stdc.stdlib : EXIT_FAILURE, EXIT_SUCCESS;

/** Current Moss Version */
const Version = "0.0.1";

public import moss.platform;

/**
 * Currently just wraps the two well known exit codes from the
 * C standard library. We will flesh this out with specific exit
 * codes to facilitate integration with scripts and tooling.
 */
enum ExitStatus
{
    Failure = EXIT_FAILURE,
    Success = EXIT_SUCCESS,
}

/**
 * Base of all our required directories
 */
const RootTree = "os";

/**
 * The HashStore directory, used for deduplication purposes
 */
const HashStore = RootTree ~ "/store";

/**
 * The RootStore directory contains our OS image root
 */
const RootStore = RootTree ~ "/root";

/**
 * The DownloadStore directory contains all downloads
 */
const DownloadStore = RootTree ~ "/download";
