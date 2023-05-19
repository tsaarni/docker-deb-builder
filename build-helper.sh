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

# Remove directory owned by _apt
trap "rm -rf /var/cache/apt/archives/partial" EXIT

log "Updating image"
apt-get update
apt-get upgrade -y --no-install-recommends
apt-mark minimize-manual -y
apt-get autoremove -y

log "Cleaning apt package cache"
apt-get autoclean

# Install extra dependencies that were provided for the build (if any)
#   Note: dpkg can fail due to dependencies, ignore errors, and use
#   apt-get to install those afterwards
if [ -d /dependencies ]; then
    log "Installing dependencies"
    dpkg -i /dependencies/*.deb
    apt-get -f install -y --no-install-recommends
fi

# Install ccache
if [ -n "${USE_CCACHE+x}" ]; then
    log "Setting up ccache"
    apt-get install -y --no-install-recommends ccache
    export CCACHE_DIR=/ccache_dir
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
debuild --prepend-path /usr/lib/ccache --preserve-envvar CCACHE_DIR -b -uc -us --sanitize-env

if [ -n "${BUILD_TWICE+x}" ]; then
    log "Building package the second time"
    debuild --prepend-path /usr/lib/ccache --preserve-envvar CCACHE_DIR -b -uc -us --sanitize-env
fi

if [ -n "${USE_CCACHE+x}" ]; then
    log "ccache statistics"
    ccache --show-stats
fi

cd /

# Run Lintian
if [ -n "${RUN_LINTIAN+x}" ]; then
    log "Running Lintian"
    apt-get install -y --no-install-recommends lintian
    adduser --system --no-create-home lintian-runner
    log "+++ Lintian Report Start +++"
    runuser -u lintian-runner -- lintian --display-experimental --info --display-info --pedantic --tag-display-limit 0 --color auto --verbose --fail-on none /build/*.changes
    log "+++ Lintian Report End +++"
fi

# Copy packages to output dir with user's permissions
if [ -n "${USER+x}" ] && [ -n "${GROUP+x}" ]; then
    chown -R "${USER}:${GROUP}" /build
fi
cp -a /build/*.deb /build/*.buildinfo /build/*.changes /output/
ls -l -A --color=auto -h /output

log "Finished"
