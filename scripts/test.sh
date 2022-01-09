#!/bin/bash

# Install protosnek repository configuration
install -D -m 00644 data/00_protosnek.conf destdir/etc/moss/repos.conf.d/00_protosnek.conf

# Build moss
./scripts/build.sh
