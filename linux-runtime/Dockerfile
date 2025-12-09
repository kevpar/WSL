# Multi-stage Dockerfile used to produce the WSLA rootfs.
#
#
# Basic usage
#
# If you're not interested in changing this Dockerfile, and just want to build,
# a rootfs using it, look here.
# To build a prod rootfs, you can use the following command, run from the
# directory containing this Dockerfile:
#   docker build --output=type=local,dest=/path .
# This will create a file named /path/rootfs.vhd, which can be used
# as your WSLA rootfs.
# If you instead want a debug rootfs (containing additional utilities), add
# this parameter to the "docker build" command:
#   --build-arg=envtype=debug
#
#
# How it works
#
# This Dockerfile makes heavy use of the "multi-stage build" feature in docker.
# Each "stage" of a build has its own "FROM foo [AS bar]"
# statement. This sets up a new base image that later statements add layers on
# top of.
# For instance, we first use "FROM [...] AS build" to create a base image that
# has the various build utilities we need. Some later stages build on top of
# this stage ("FROM build AS [...]") so that they can use the build tools.
# We also use the Dockerfile statements:
# - COPY --from=<stage> [...]
# - RUN --mount=type=bind,from=<stage> [...]
# These allow us to copy or mount files from a previous stage into the current
# stage.
#
# We support creating both a prod and a debug rootfs. The prod rootfs is
# intended to be what is shipped, and tries to be as minimal as possible.
# This is done by using tdnf (the Azure Linux package manager) to download
# and install packages in the /rootfs dir of a stage based on "build", and then
# copying these files into a "FROM scratch" stage. The debug rootfs, on the
# other hand, is based on the Azure Linux container image, so it has a
# functional package manager.
#
# Based on the value of the envtype Dockerfile argument, the rootfs stage
# builds on top of either the rootfs_prod or rootfs_debug stage. This
# allows us to conditionally bring in the correct rootfs base depending
# on if a prod or debug build is desired.
# The envtype arg defaults to prod, but can be changed by passing the following
# to "docker build":
#   --build-arg=envtype=debug
#
# This directory (called the "context" by docker) also contains packages.txt.
# This file contains the set of Azure Linux packages to be installed in the
# rootfs for both prod and debug rootfs builds.
#
#
# Advanced usage
#
# Here you can find details on some niche scenarios that can be done with this
# Dockerfile.
# - Save the rootfs as a docker image:
#     docker build --target rootfs --tag rootfs:latest
# - Export the rootfs as a directory instead of a VHD:
#     docker build --target rootfs --output=type=local,dest=/path .
#   /path will contain the files of the rootfs, unpacked.
# - Export the rootfs as a tar instead of a VHD:
#     docker build --target rootfs --output=type=tar,dest=/path.tar .
#   /path.tar will be a tarball containing the files of the rootfs.


# Can be 'prod' or 'debug'. A debug image will be larger and include additional
# utilities like a package manager.
ARG envtype=prod


# build stage
# Produces the base image used for various build utility operations, for
# instance, cloning repos and building code.
FROM mcr.microsoft.com/azurelinux/base/core:3.0 AS build

RUN tdnf install -y \
    ca-certificates \
    golang \
    git \
    build-essential


# nerdctl stage
# Starts from the build stage, then clones and builds nerdctl.
FROM build AS nerdctl

RUN git clone --branch v2.2.0 --depth 1 https://github.com/containerd/nerdctl.git /src/nerdctl
WORKDIR /src/nerdctl
RUN CGO_ENABLED=1 go build -o /out/nerdctl ./cmd/nerdctl

RUN mkdir /out/licenses
RUN cp LICENSE NOTICE /out/licenses


# packages_prod stage
# Downloads the packages needed for the prod rootfs and installs them into the
# /rootfs directory. This must be done on of the build stage because the actual
# prod rootfs is based on scratch, so it can't install its own packages.
FROM build AS packages_prod

RUN --mount=type=bind,target=/context \
    tdnf install --releasever=3.0 --installroot=/rootfs -y \
    $(cat /context/packages.txt)

RUN tdnf clean --releasever=3.0 --installroot=/rootfs all


# rootfs_prod stage
# Produces the base of the rootfs from scratch.
# The final touches are added in the rootfs stage.
FROM scratch AS rootfs_prod

COPY --from=packages_prod /rootfs /


# rootfs_debug stage
# Produces the base of the rootfs using Azure Linux, with the packages we want added on top.
# The final touches are added in the rootfs stage.
FROM mcr.microsoft.com/azurelinux/base/core:3.0 AS rootfs_debug

RUN --mount=type=bind,target=/context \
    tdnf install -y \
    $(cat /context/packages.txt)


# rootfs stage
# Produces a filesystem containing the rootfs files before tar/vhd creation.
# Builds on top of either rootfs_prod or rootfs_debug, based on the envtype argument.
FROM rootfs_${envtype} AS rootfs

COPY --from=nerdctl /out/nerdctl /bin/nerdctl
COPY --from=nerdctl /out/licenses /usr/share/licenses/nerdctl

RUN /sbin/busybox --install -s


# vhd stage
# Tars the rootfs stage and converts it to a VHD.
FROM build AS vhd

RUN --mount=type=bind,from=rootfs,target=/rootfs \
    tar -cf /rootfs.tar -C /rootfs .

RUN go run github.com/Microsoft/hcsshim/cmd/tar2ext4@v0.13.0 -vhd -i /rootfs.tar -o /rootfs.vhd


# final stage
# Produces a filesystem with a single file, /rootfs.vhd.
FROM scratch

COPY --from=vhd /rootfs.vhd /