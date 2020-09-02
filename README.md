### moss

This repository is a placeholder for our package manager, once we enter
stage4 of the bootstrap. Certain decisions have already been made:

 - Implemented in the `D` programming language.
 - Build tooling will be separate to the package manager
 - Repository management (devops side) will also be separate
 - Optimized for crumby connections (deltas, small indexes, connection reuse)
 - **Subscription** and **capability** based (+ package variants)
 - Plus whatever we listed on the About page.
 - Mixed source/binary repo support

Development won't really start until such point as stage3 bootstrap has
been completed, therefore we won't be monitoring the GitHub issues for
discussions.

We have a fairly solid idea internally of how the package manager will
look, and will make that public and documented at the first appropriate
time.

### Why Not Meson

We cannot afford to dynamically link with Phobos as we're a system
critical component. Meson enforces dynamic linking with Phobos by
default now: https://github.com/mesonbuild/meson/pull/6796
