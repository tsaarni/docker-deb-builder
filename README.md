
# Creating Debian packages in Docker container

## Overview

Docker can be used to set up a clean build environment for Debian
packaging.  This tutorial shows how to create a container with
required build tools and how to use it to build packages.

## Create build environment

Start by building a container that will act as package build environment:

    docker build -t docker-deb-builder:17.04 -f Dockerfile-ubuntu-17.04 .

In this example the target is Ubuntu 17.04 but you can create and
modify `Dockerfile-nnn` to match your target environment.

## Building packages

First download or git clone the source code of the package you are
building:

    git clone ... ~/my-package-source

The source code should contain subdirectory called `debian` with at
least a minimum set of packaging files: `control`, `copyright`,
`changelog` and `rules`.

Clone the
[docker-deb-builder](https://github.com/tsaarni/docker-deb-builder)
(the repository you are reading now) and run the build script to see
usage:

    $ ./build
    usage: build [options...] SOURCEDIR
    Options:
      -i IMAGE  Name of the docker image (including tag) to use as package build environment.
      -o DIR    Destination directory to store packages to.
      -d DIR    Directory that contains other deb packages that need to be installed before build.

To build Debian packages run following commands:

    # create destination directory to store the build results
    mkdir output

    # build package from source directory
    ./build -i docker-deb-builder:17.04 -o output ~/my-package-source

After successful build you will find the `.deb` files in `output`
directory.

Sometimes build might require dependencies that cannot be installed with
`apt-get build-dep`.  You can install them into the build environment
by passing option `-d DIR` where DIR is a directory with `*.deb` files
in it.

    ./build -i docker-deb-builder:17.04 -o output -d dependencies ~/my-package-source

## Integrating with CI

In this tutorial all package-specific build dependencies are installed
from scratch each time build is executed in the container.  The
benefit is that the container is generic and reusable for building any
package but the installation of build-time dependencies can add up to
considerable overhead, both in time and bandwidth.  This overhead may
not be acceptable when building packages as part of continuous
integration pipeline.  One possible solution to reduce overhead is to
install package-specific build dependencies into build environment
container.
