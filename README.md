### moss

This repository supports the development of the new system software manager for
Serpent OS. It is not intended as a replacement for other package managers,
or indeed, even "next generation". Simply it aims to be a
package manager with a focus on reliability and trust.

#### Build prerequisites

`moss` (and its own dependencies) depends on a couple of system libraries
and development headers, including (in fedora package names format):

- `cmake`, `meson` and `ninja`
- `libcurl` and `libcurl-devel`
- `libzstd` and `libzstd-devel`
- `lmdb` and `lmdb-devel`
- `xxhash-libs` and `xxhash-devel`

#### Building

    meson build/
    meson compile -C build/

#### Running

    build/moss -h

#### Package Format

The `stone` container format is entirely binary encoded, consisting of
well-structured `Payload` containers. Each payload is preceded by a
fixed header, defining the **type**, version, compression, etc.

For the majority of packages, 4 payloads are employed:

 - Meta: Strongly typed key-value pairs of metadata
 - Content: Concatenated, de-duplicated binary blob containing all file data, **no** metadata.
 - Layout: Strongly typed records defining the final filesystem layout of the package
 - Index: Series of indices making the content addressable.

#### Stateless by default

We will absolutely forbid the inclusion of non-OS files within packages,
to prevent situations where conflicts or merges are required. This requires
more effort on the side of the OS development to ensure proper integration.

#### Atomic update

moss will reuse the same concept found in next-generation package managers
to support atomic updates. This involves switching a pointer on the rootfs
to point to the new `usr` tree within an exploded OS rootfs.

#### Deduplication

During the caching stage of package installation, the unique files within the
content payload are extracted to the global content store if not already present.
Each unique asset is indexed by an `xxhash` key to allow a fast deduplication
strategy.

During transaction application, unique content is then hardlinked into the staging
tree.

#### Rollbacks

Each mutation-transaction can create a new versioned OS tree, so we will support
atomically updating the system to an earlier version. For updates where a reboot
is required, we will defer updating the pointer until early boot.

#### Proposed Layout

While the paths may change, we are considering a layout similar to the one
listed below:


    ├── bin -> os/store/installation/0/usr/bin
    ├── boot
    ├── etc
    ├── home
    │   └── root
    ├── lib -> os/store/installation/0/usr/lib
    ├── lib64 -> os/store/installation/0/usr/lib
    ├── media
    ├── root -> home/root
    ├── run
    ├── sbin -> os/store/installation/0/usr/bin
    ├── os
    │   └── store
    │       ├── hash
    │       │   └── 96918944c1e369411ddb68e8f4f4f479a99f7eccc67ba55b2ce6433901f7832d
    │       └── installation
    │           └── 0
    │               └── usr
    │                   ├── bin
    │                   │   └── bash
    │                   ├── include
    │                   ├── lib
    │                   ├── lib64 -> lib
    │                   ├── sbin -> bin
    │                   └── share
    ├── usr -> os/installation/0/usr
    └── var

It is entirely possible we'll choose to collapse paths and rely on a single
link, `/usr`, with the rest being statically defined.

#### How Does It Differ?

We will only permit **known configurations**, and still be a fairly traditional
OS. However, instead of creating the OS from a large series of symlinks, the
target rootfs will be composed primarily of hardlinks, allowing mass deduplication
**and** a far simpler implementation. By enforcing certain constraints on the
layout and OS (i.e. stateless, usr merge) we can get away with a minimal number
of support symlinks, and still be fully compatible with other distributions
in terms of introspection and chrooting.

#### Inspiration

moss has been inspired by a number of tools, including (but not limited to):

 - eopkg/pisi
 - rpm
 - swupd
 - nix/guix

Our approach is a hybrid one, traditional package management with internal
features found only in next-gen package managers. This helps us to reduce
the testing matrix and potential configurations to a sane norm, and lock
OS releases to their corresponding kernel releases.
