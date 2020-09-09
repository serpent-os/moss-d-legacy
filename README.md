### moss

We have only just started development of moss, the Serpent OS package
manager. This will happen in various stages, adding functionality and
refining core functionality as we go along.

Our first goal is to facilitate the bootstrap process of Serpent OS,
thus the package manager will be **very** simple and quite buggy.
Our initial focus is in building the **package format** and allowing
local installation of packages.

Eventually we will progress to repository and fetching support, but
doing so too early will hinder progress on all fronts.

This package manager is implemented in the D Programming Language,
and we strongly recommend using the `ldc` compiler.

The command line interface takes direct inspiration from the
`eopkg` package manager in Solus, in turn a fork of `pisi` from
Pardus.


#### Modules

moss/cli

    Implements the command line interface

moss/build

    Implements support for building packages

moss/format

    Implement format support, including binary and source build formats
    If required, we can split this into a submodule down the line.
