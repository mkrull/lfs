#!/bin/bash

function install_binutils {
    local build_dir="${LFS_BUILD_DIR}/binutils"
    local pkg="binutils-2.24"
    local archive="${pkg}.tar.bz2"
    local src="${LFS_ROOT}/${LFS_SRC_DIR}/${LFS_VERSION}/${pkg}"
    local prefix="${LFS_ROOT}/${LFS_TOOLCHAIN}"

    mkdir -p "${build_dir}"

    pushd ${LFS_SRC_DIR}/${LFS_VERSION} >&3

    if [ -d "${pkg}" ]; then
        echo "${pkg} already unpacked"
    else
        echo -n "unpacking ${pkg}"
        tar xfpv ${archive} >&3
        echo " :: done."
    fi
    popd >&3

    pushd ${build_dir} >&3
        echo -n "configure ${pkg}"
        ${src}/configure                           \
            --prefix="${prefix}"                   \
            --with-sysroot="${LFS_ROOT}"           \
            --with-lib-path="${prefix}/lib"        \
            --target="${LFS_TARGET}"               \
            --disable-nls                          \
            --disable-werror  1>&3 2>&3
        echo " :: done."
        echo -n "make ${pkg} (will take a while)"
        make 1>&3 2>&3 && make install >&3
        echo " :: done."
    popd >&3
}

function install_gcc {
    echo "gcc :: not yet implemented"
}

function setup_dirs {
    if [ ${LFS_DEBUG} -eq 1 ]; then
        exec 3>&1
    else
        exec 3>/dev/null
    fi

    echo "creating directories"
    mkdir -p "${LFS_SRC_DIR}"
    mkdir -p "${LFS_BUILD_DIR}"
    mkdir -p "${LFS_TOOLCHAIN}"

    case ${LFS_TARGET} in
        x86_64*)
            if [ ! -l "${LFS_TOOLCHAIN}/lib64" ]; then
                mkdir -p "${LFS_TOOLCHAIN}/lib" && ln -sv lib "${LFS_TOOLCHAIN}/lib64"
            fi
            ;;
    esac
}

function prepare {
    pushd ${LFS_SRC_DIR} >&3

    if [ -f "${LFS_PKG_TAR}" ]; then
        echo "packages archive found"
    else
        echo -n "downloading packages (may take a while)"
        wget http://ftp.lfs-matrix.net/pub/lfs/lfs-packages/lfs-packages-${LFS_VERSION}.tar >&3
        echo " :: done."
    fi

    local pkg_list=$(tar tf "${LFS_PKG_TAR}"|grep -v '/$')

    if [ ! -f "${LFS_PKG_TAR}" ]; then
        popd  >&3
        echo "downloading packages failed"
        exit 1
    fi

    for pkg in ${pkg_list}; do
        if [ -f $pkg ]; then
            echo "$(basename $pkg) found"
        else
            echo -n "extracting $(basename $pkg) from archive"
            tar xfpv "${LFS_PKG_TAR}" ${pkg} >&3
            echo " :: done."
        fi
    done

    popd  >&3
}
