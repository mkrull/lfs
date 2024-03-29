#!/bin/sh

LFS_DEBUG=0
LFS_VERSION="7.5"
LFS_TARGET="$(uname -m)-lfs-linux-gnu"
LFS_BUILD_DIR="tmp/lsf-build"
LFS_TOOLCHAIN="tmp/toolchain"
LFS_SRC_DIR="usr/src"
LFS_PKG_TAR="lfs-packages-${LFS_VERSION}.tar"
LFS_ROOT=$(pwd)
LFS_NPROC=printf "%s" $(nproc)
LFS_BUILD_LOG="${LFS_ROOT}/build.log"

source ./functions.sh

setup_dirs
prepare
install_binutils
install_gcc
install_linux_headers
install_glibc

exit 0
