# moss

Traditionally, Linux distribution use is largely driven by the use of package management. Unfortunately, package managers were built a long time ago and are full of many flaws.

In today's world, traditional package managers are being replaced in order to provide reliability and immutability. Unfortunately that has led to a great reduction in flexibility and composition with the Linux experience.

The primary aim of `moss` is to blend the flexibility, ownership and freedom of traditional package management with the features expected by default in appliance-targeted package managers.

With moss the smallest unit of granularity is once again a package. In addition, moss has complete dependency resolution, parallel fetching + caching, deduplication, offline rollbacks, priority based `collections` ("binary repository"), as well as fully atomic updates.

All of this is achieved by leveraging common sense, the Linux kernel and remaining agnostic of filesystems.

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

#### Atomic update

To **apply** a moss transaction to the filesystem - we first build it in a staging tree. Every transaction is a unique tree and created entirely fresh using the content store. The complete `/usr` tree is built and populated using hardlinks - we refer to this as blitting.

When completed, we activate the new system by way of `renameat2()` with `RENAME_EXCHANGE`  to atomically swap the new system with the old one.

Note that `moss` enforces a usr-merge pattern which allows this method to work.

#### Deduplication

During the caching stage of package installation, the unique files within the
content payload are extracted to the global content store if not already present.
Each unique asset is indexed by an `xxhash` key to allow a fast deduplication
strategy.

During transaction application, unique content is then hardlinked into the staging
tree.

#### Stateless by default

By virtue of **design**, `.stone` packages are forbidden from including any
path outside of the `/usr` tree. This is to enforce proper stateless decisions
are made with the OS to permit vendor + administration data/configuration split.


#### Rollbacks

Thanks to deduplication, it is very cheap to retain our transactions on disk.
Thus, offline rollbacks are entirely possible by swapping `/usr` for an older
transaction.

#### Package Format

The `stone` container format is entirely binary encoded, consisting of
well-structured `Payload` containers. Each payload is preceded by a
fixed header, defining the **type**, version, compression, etc.

For the majority of packages, 4 payloads are employed:

 - Meta: Strongly typed key-value pairs of metadata
 - Content: Concatenated, de-duplicated binary blob containing all file data, **no** metadata.
 - Layout: Strongly typed records defining the final filesystem layout of the package
 - Index: Series of indices making the content addressable.


#### Proposed Layout

While the paths may change, we are considering a layout similar to the one
listed below:


    /
    ├── bin -> usr/bin
    ├── lib -> usr/lib
    ├── .moss
    │   ├── assets
    │   │   └── v2
    │   │       ├── 5f
    │   │       │   └── ee
    │   │       │       └── 65
    │   │       │           └── 5fee65451cc8788410cff93cdbe7f904
    │   │       └── 6d
    │   │           └── c2
    │   │               └── 91
    │   │                   └── 6dc2910a903a7e047335e51d0c6a7abc
    │   ├── cache
    │   │   ├── content
    │   │   └── downloads
    │   │       └── v1
    │   │           └── ee0a7
    │   │               └── 8a584
    │   │                   └── ee0a7e10a5b3cfd4f2b567e63bba6d5fc42282e296701455077c32987998a584
    ├── sbin -> usr/sbin
    └── usr
        ├── bin
        │   └── neofetch
        ├── share
        │   └── man
        │       └── man1
        │           └── neofetch.1
        └── .stateID


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
