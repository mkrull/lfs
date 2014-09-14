#!/bin/bash

function extract_pkg {
    local pkg=$1
    local atype=$2
    local archive="${pkg}.${atype}"
    pushd ${LFS_SRC_DIR}/${LFS_VERSION} >&3

    if [ -d "${pkg}" ]; then
        echo "${pkg} already unpacked"
    else
        echo -n "unpacking ${pkg}"
        tar xfpv ${archive} >&3
        echo " :: done."
    fi
    popd >&3
}

function install_binutils {
    local build_dir="${LFS_BUILD_DIR}/binutils"
    local pkg="binutils-2.24"
    local atype="tar.bz2"
    local archive="${pkg}.${atype}"
    local src="${LFS_ROOT}/${LFS_SRC_DIR}/${LFS_VERSION}/${pkg}"
    local prefix="${LFS_ROOT}/${LFS_TOOLCHAIN}"

    mkdir -p "${build_dir}"

    extract_pkg ${pkg} ${atype}

    pushd ${build_dir} >&3
        echo -n "configure ${pkg}"
        ${src}/configure                    \
            --prefix="${prefix}"            \
            --with-sysroot="${LFS_ROOT}"    \
            --with-lib-path="${prefix}/lib" \
            --target="${LFS_TARGET}"        \
            --disable-nls                   \
            --disable-werror  1>&3 2>&3
        echo " :: done."
        echo -n "make ${pkg} (will take a while)"
        make -j${LFS_NPROC} 1>&3 2>&3 && make install >&3
        echo " :: done."
    popd >&3
}

function install_gcc {
    prepare_gcc
    local abs_chain="${LFS_ROOT}/${LFS_TOOLCHAIN}"
    local build_dir="${LFS_BUILD_DIR}/gcc"
    local pkg="gcc-4.8.2"
    local src="${LFS_ROOT}/${LFS_SRC_DIR}/${LFS_VERSION}/${pkg}"
    local prefix="${LFS_ROOT}/${LFS_TOOLCHAIN}"

    mkdir -p "${build_dir}"

    pushd ${build_dir} >&3
        echo -n "configure ${pkg}"
        ${src}/configure                                         \
            --target=${LFS_TARGET}                               \
            --prefix=${prefix}                                   \
            --with-sysroot=$LFS_ROOT                             \
            --with-newlib                                        \
            --without-headers                                    \
            --with-local-prefix=${abs_chain}                     \
            --with-native-system-header-dir=${abs_chain}/include \
            --disable-nls                                        \
            --disable-shared                                     \
            --disable-multilib                                   \
            --disable-decimal-float                              \
            --disable-threads                                    \
            --disable-libatomic                                  \
            --disable-libgomp                                    \
            --disable-libitm                                     \
            --disable-libmudflap                                 \
            --disable-libquadmath                                \
            --disable-libsanitizer                               \
            --disable-libssp                                     \
            --disable-libstdc++-v3                               \
            --enable-languages=c,c++                             \
            --with-mpfr-include=$(pwd)/../${pkg}/mpfr/src        \
            --with-mpfr-lib=$(pwd)/mpfr/src/.libs 1>&3 2>&3

        echo " :: done."
        echo -n "make ${pkg} (will take a while)"
        make 1>&3 2>&3
        make install 1>&3 2>&3
        ln -s libgcc.a $(${abs_chain}/bin/${LFS_TARGET}-gcc -print-libgcc-file-name | sed 's/libgcc/&_eh/')
        echo " :: done."
    popd >&3
}

function prepare_gcc {
    local gcc_pkg="gcc-4.8.2"
    local gcc_atype="tar.bz2"
    local mpfr_pkg="mpfr-3.1.2"
    local mpfr_atype="tar.xz"
    local gmp_pkg="gmp-5.1.3"
    local gmp_atype="tar.xz"
    local mpc_pkg="mpc-1.0.2"
    local mpc_atype="tar.gz"

    extract_pkg ${gcc_pkg} ${gcc_atype}
    extract_pkg ${mpfr_pkg} ${mpfr_atype}
    extract_pkg ${gmp_pkg} ${gmp_atype}
    extract_pkg ${mpc_pkg} ${mpc_atype}

    local gcc_dir="${LFS_SRC_DIR}/${LFS_VERSION}/${gcc_pkg}"
    #mv "${LFS_SRC_DIR}/${LFS_VERSION}/${mpc_pkg}" "${gcc_dir}/mpc"
    #mv "${LFS_SRC_DIR}/${LFS_VERSION}/${mpfr_pkg}" "${gcc_dir}/mpfr"
    #mv "${LFS_SRC_DIR}/${LFS_VERSION}/${gmp_pkg}" "${gcc_dir}/gmp"

    set_gcc_toolchain ${gcc_dir}
}

function set_gcc_toolchain {
    local gcc_dir=$1
    local abs_chain="${LFS_ROOT}/${LFS_TOOLCHAIN}"
    local replace_ld="s@/lib\\(64\)\\?\\(32\\)\\?/ld@${abs_chain}&@g"
    local replace_lib_base="s@/usr@${abs_chain}@g"
    pushd ${gcc_dir} >&3
    for file in \
        $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h)
    do
        cp -u $file{,.orig}
        sed -e ${replace_ld} \
            -e ${replace_lib_base} $file.orig > $file
        echo "
        #undef STANDARD_STARTFILE_PREFIX_1
        #undef STANDARD_STARTFILE_PREFIX_2
        #define STANDARD_STARTFILE_PREFIX_1 \"${abs_chain}/lib/\"
        #define STANDARD_STARTFILE_PREFIX_2 \"\"" >> $file
        touch $file.orig
    done
    sed -i '/k prot/agcc_cv_libc_provides_ssp=yes' gcc/configure
    popd  >&3
}

function install_linux_headers {
    local pkg="linux-3.13.3"
    local atype="tar.xz"
    local include_dir="${LFS_ROOT}/${LFS_TOOLCHAIN}/include"

    extract_pkg ${pkg} ${atype}

    echo -n "installing linux headers"
    pushd ${LFS_SRC_DIR}/${LFS_VERSION}/${pkg} >&3
        mkdir -p ${include_dir}
        make mrproper >&3
        make INSTALL_HDR_PATH=dest headers_install >&3
        cp -r dest/include/* ${include_dir}
    popd >&3
    echo " :: done."
}

function install_glibc {
    local pkg="glibc-2.19"
    local atype="tar.xz"
    local fhc_patch="glibc-2.19-fhs-1.patch"
    local build_dir="${LFS_BUILD_DIR}/glibc"
    local prefix="${LFS_ROOT}/${LFS_TOOLCHAIN}"

    mkdir -p "${build_dir}"

    extract_pkg ${pkg} ${atype}

    pushd ${LFS_SRC_DIR}/${LFS_VERSION}/${pkg} >&3
        patch -b -p1 -s -i ${LFS_ROOT}/${LFS_SRC_DIR}/${LFS_VERSION}/${fhc_patch}
    popd >&3

    pushd ${build_dir} >&3
        ${LFS_ROOT}/${LFS_SRC_DIR}/${LFS_VERSION}/${pkg}/configure                           \
            --prefix=${prefix}                                                               \
            --host=$LFS_TARGET                                                               \
            --build=$(${LFS_ROOT}/${LFS_SRC_DIR}/${LFS_VERSION}/${pkg}/scripts/config.guess) \
            --disable-profile                                                                \
            --enable-kernel=2.6.32                                                           \
            --with-headers=${prefix}/include                                                 \
            libc_cv_forced_unwind=yes                                                        \
            libc_cv_ctors_header=yes                                                         \
            libc_cv_c_cleanup=yes 1>&3 2>&3

        echo -n "make ${pkg} (will take a while)"
        make #1>&3 2>&3
        make install #1>&3 2>&3
        echo " :: done."
    popd >&3
}

function setup_dirs {
    if [ ${LFS_DEBUG} -eq 1 ]; then
        exec 3>&1
    else
        exec 3>${LFS_BUILD_LOG}
    fi

    echo "creating directories"
    mkdir -p "${LFS_SRC_DIR}"
    mkdir -p "${LFS_BUILD_DIR}"
    mkdir -p "${LFS_TOOLCHAIN}"

    case ${LFS_TARGET} in
        x86_64*)
            if [ ! -L "${LFS_TOOLCHAIN}/lib64" ]; then
                mkdir -p "${LFS_TOOLCHAIN}/lib" >&3 && ln -s lib "${LFS_TOOLCHAIN}/lib64"
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

    echo -n "extracting packages"
    for pkg in ${pkg_list}; do
        if [ -f $pkg ]; then
            echo "$(basename $pkg) found"
        else
            tar xfpv "${LFS_PKG_TAR}" ${pkg} >&3
        fi
    done
    echo " :: done."

    popd  >&3
}
