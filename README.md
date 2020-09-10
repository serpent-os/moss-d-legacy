### moss

This repository supports the development of the new package manager for
Serpent OS. It is not intended as a replacement for other package managers,
or indeed, even "next generation". Simply it aims to be a traditional
package manager with a focus on reliability and trust.

#### Package Format

Our plan is a binary format that contains a well-known and versioned header,
offsets, extendable meta tables and a payload. The payload will be a series
of hash-keyed blobs, storing only unique content. This ensures that a payload
is deduplicated by default.

#### Stateless by default

We will absolutely forbid the inclusion of non-OS files within packages,
to prevent situations where conflicts or merges are required. This requires
more effort on the side of the OS development to ensure proper integration.

#### Atomic update

moss will reuse the same concept found in next-generation package managers
to support atomic updates. This involves switching a pointer on the rootfs
to point to the new `usr` tree within an exploded OS rootfs.

#### Deduplication

moss will extract unique blobs from packages to a shared cache on the
system, ensuring unique files are only present **once**. Additionally, a rootfs
will be largely constructed by hardlinking the cache out to the final location
within an OS subtree, ready for pointer update. (`/usr`)

#### Rollbacks

Each mutation-transaction can create a new versioned OS tree, so we will support
atomically updating the system to an earlier version. For updates where a reboot
is required, we will defer updating the pointer until early boot.

#### Proposed Layout

While the paths may change, we are considering a layout similar to the one
listed below:


    ├── bin -> serpent/store/installation/0/usr/bin
    ├── boot
    ├── etc
    ├── home
    │   └── root
    ├── lib -> serpent/store/installation/0/usr/lib
    ├── lib64 -> serpent/store/installation/0/usr/lib
    ├── media
    ├── root -> home/root
    ├── run
    ├── sbin -> serpent/store/installation/0/usr/bin
    ├── serpent
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
    ├── usr -> serpent/installation/0/usr
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

#### Impact On Other Tooling

We will likely need to work upstream with `clr-boot-manager` to add direct
support for our system, so that each kernel is specific to a transaction or
repository release. Additionally the kernel will need to arguments passed
to it so our earlyboot code can switch to the appropriate system version.

This will allow us to automatically have boot entries for the last X versions
of Serpent OS, making it a far more robust and reliable system for administrators
and users alike.
