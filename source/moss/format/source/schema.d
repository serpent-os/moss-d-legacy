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

module moss.format.source.schema;

/**
 * To simplify internal type unmarshalling we have our own basic
 * types of yaml keys
 */
enum YamlType
{
    Single = 0,
    Array = 1,
    Map = 2,
}

/**
 * UDA to help unmarshall the correct values.
 */
struct YamlSchema
{
    /** Name of the YAML key */
    string name;

    /** Is this a mandatory key? */
    bool required = false;

    /** Type of value to expect */
    YamlType type = YamlType.Single;
}
