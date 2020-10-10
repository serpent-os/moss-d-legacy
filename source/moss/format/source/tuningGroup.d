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

module moss.format.source.tuningGroup;

public import moss.format.source.schema;

/**
 * Each TuningOption can set one or more TuningFlag combinations to
 * be enabled when in the ENABLED or DISABLED state.
 *
 * Most flags will not turn anything *on* when disabled, but to ensure
 * consistency between compiler versions we'll explicitly set their
 * counter value, i.e. -fcommon vs -fno-common.
 *
 * Thus, enabling a tuning option or disabling it involves collecting
 * the full set of tuning flag *names* from either the enabled or disabled
 * states, condensing them, and building the full flag set from there.
 */
final struct TuningOption
{
    @YamlSchema("enabled", false, YamlType.Array) string[] onEnabled;
    @YamlSchema("disabled", false, YamlType.Array) string[] onDisabled;
}

/**
 * A TuningGroup may contain default boolean "on" "off" values, or
 * it may contain them via choices, i.e. "=speed"
 */
final struct TuningGroup
{
    /* Root namespace group option */
    TuningOption root;
    TuningOption[string] choices;

    @YamlSchema("default") string defaultChoice = null;
}
