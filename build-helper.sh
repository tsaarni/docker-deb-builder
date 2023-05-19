#!/bin/bash

set -euo pipefail

# This script is executed within the container as root.  It assumes
# that source code with debian packaging files can be found at
# /source-ro and that resulting packages are written to /output after
# successful build.  These directories are mounted as docker volumes to
# allow files to be exchanged between the host and the container.

if [ -t 0 ] && [ -t 1 ]; then
    Blue='\033[0;34m'
    Reset='\033[0m'
else
    Blue=
    Reset=
fi

function log {
    echo -e "[${Blue}*${Reset}] $1"
}

log "Updating image"
apt-get update
apt-get upgrade -y --no-install-recommends
apt-mark minimize-manual -y
apt-get autoremove -y

# Install extra dependencies that were provided for the build (if any)
#   Note: dpkg can fail due to dependencies, ignore errors, and use
#   apt-get to install those afterwards
if [ -d /dependencies ]; then
    log "Installing dependencies"
    dpkg -i /dependencies/*.deb
    apt-get -f install -y --no-install-recommends
fi

# Make read-write copy of source code
log "Copying source directory"
mkdir -p /build
cp -a /source-ro /build/source
cd /build/source

# Install build dependencies
log "Installing build dependencies"
mk-build-deps -ir -t "apt-get -o Debug::pkgProblemResolver=yes -y --no-install-recommends"

# Build packages
log "Building package"
debuild -b -uc -us --sanitize-env

# Copy packages to output dir with user's permissions
chown -R "$USER:$GROUP" /build
cp -a /build/*.deb /build/*.buildinfo /build/*.changes /output/
ls -l -A --color=auto -h /output

log "Finished"
