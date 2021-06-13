#!/bin/sh

WORK_DIR=`pwd`
DIST_DIR="/Data/Port/BB10/bb10-gcc9/Downloads/"
SRC_DIR="${WORK_DIR}/src"
mkdir -p ${DIST_DIR} ${SRC_DIR}

. ${WORK_DIR}/download.sh
. ${WORK_DIR}/env.sh

PREFIX="${APP_ROOT}/${QNX_VERSION}"

#-------------------------------------------------------------------------------
# host flags

#------------------------------------------------------------------------------
#target flags

TARGET_DEFS="-D__QNXNTO__ -D__QNX__ -D__unix__ -D__unix -D__ELF__ \
-D__ARM__ -D__arm__ -D__ARMEL__ -D__LITTLEENDIAN__ -D_LARGEFILE64_SOURCE \
-D_REENTRANT -D_FORTIFY_SOURCE=2 -D__NEWLIB__"

TARGET_CDEFS="${TARGET_DEFS}"

TARGET_CXXDEFS="${TARGET_DEFS} -D_NO_CPP_INLINES"

TARGET_CPUFLAGS="-mlittle-endian -mthumb -mcpu=cortex-a9 \
-mfpu=neon-vfpv3  -mfloat-abi=softfp"

TARGET_ASFLAGS=

TARGET_CCFLAGS="-O3 -Wall -W -fPIC -pthread -pipe \
-fstack-protector -fstack-protector-strong"

TARGET_CFLAGS="${TARGET_CDEFS} ${TARGET_CPUFLAGS} ${TARGET_CCFLAGS}"

TARGET_CXXFLAGS="${TARGET_CXXDEFS} ${TARGET_CPUFLAGS} ${TARGET_CCFLAGS}"

TARGET_LDFLAGS="-Wl,--sysroot=${QNX_PREBUILT} -Wl,-rpath-link="${QNX_PREBUILT_GCCLIB}" \
-Wl,-rpath-link==/lib -Wl,-rpath-link==/usr/lib -lc"

export CC_FOR_TARGET="${QNX_ABI}-gcc"
export CXX_FOR_TARGET="${QNX_ABI}-g++"
export AS_FOR_TARGET="${QNX_ABI}-as"
export LD_FOR_TARGET="${QNX_ABI}-ld"
export CFLAGS_FOR_TARGET="${TARGET_CFLAGS}"
export CXXFLAGS_FOR_TARGET="${TARGET_CXXFLAGS}"
export LDFLAGS_FOR_TARGET="${TARGET_LDFLAGS}"

#-------------------------------------------------------------------------------

# will be set to stage(binutils|gcc), (respective version)
BUILD_STAGE="$"
BUILD_VER=
BUILD_SRC=
MAKE_TARGET="all"

doPrep() {
	echo "Copying BlackBerry libraries..."	
	mkdir -p ${QNX_TARGET}
	
 	if [ ! -f ${WORK_DIR}/have-patched-qnx ]; then
		cp -r ${BBNDK_TARGET}/usr/include ${QNX_TARGET}/include
		
		# patch QNX headers
		cd ${QNX_TARGET}
		mv include/c++ include/libstdc++
		
		tar xzf ${WORK_DIR}/qnx-include.patch.tar.gz || exit 1
		patch -ruN -p1 -d include < qnx-include.patch || exit 1
		rm qnx-include.patch

		# prebuilt directories
		# separate folders for libstdc++, libcpp(qnx licensed), libc++ (future clang)
		mkdir -p ${QNX_PREBUILT}/lib
		mkdir -p ${QNX_PREBUILT}/usr/lib
		mkdir -p ${QNX_PREBUILT_GCCLIB}

		# copy old libs
		cp -r ${BBNDK_TARGET}/${QNX_ARCH}/lib/* ${QNX_PREBUILT}/lib
		mv ${QNX_PREBUILT}/lib/gcc/4* ${QNX_PREBUILT_GCCLIB}/..
		rm -rf ${QNX_PREBUILT}/lib/gcc

		# move gcc libs
		# we keep qnx-provided crt1 and mcrt1
		for file in crti.o crtn.o; do
			mv ${QNX_PREBUILT}/lib/${file} ${QNX_PREBUILT_GCCLIB}/../4.6.3
		done	
		for file in stdc++ asan gomp mudflap; do
			mv ${QNX_PREBUILT}/lib/lib${file}* ${QNX_PREBUILT_GCCLIB}/../4.6.3
		done
		# copy old host gcc libs
		cp -r ${BBNDK_HOST}/usr/lib/gcc/${BBNDK_ABI}/4.* ${QNX_PREBUILT_GCCLIB}/..
		
		# copy blackberry libs
		mkdir -p ${QNX_HOST}/lib
		cp -r ${BBNDK_HOST}/usr/lib/* ${QNX_HOST}/lib
		rm -rf ${QNX_HOST}/lib/gcc

		# copy blackberry tools
		mkdir -p ${QNX_BIN}
		cp ${WORK_DIR}/bin/* ${QNX_BIN}

		# user libraries
		mkdir -p ${QNX_PREBUILT}/usr/lib
		cp -r ${BBNDK_TARGET}/${QNX_ARCH}/usr/lib/* ${QNX_PREBUILT}/usr/lib
	
		echo `date` > ${WORK_DIR}/have-patched-qnx

	fi
}

doPatch() {
	doDownload
	doExtract

	cd ${SRC_DIR}

	# patch binutils
	if [ ! -f ${WORK_DIR}/have-patched-binutils ]; then
		if [ ! -f ${BINUTILS_SRC}.patch ]; then
			tar xzf ${WORK_DIR}/${BINUTILS_SRC}.patch.tar.gz || exit 1
		fi
		patch -ruN -p1 -d ${BINUTILS_SRC} < ${BINUTILS_SRC}.patch || exit 1
		cd ${SRC_DIR}/${BINUTILS_SRC}/bfd && autoreconf -f || exit 1
		cd ${SRC_DIR}/${BINUTILS_SRC}/opcodes && autoreconf -f || exit 1
		echo `date` > ${WORK_DIR}/have-patched-binutils
	fi 

	cd ${SRC_DIR}
  
	# patch gcc
	if [ ! -f ${WORK_DIR}/have-patched-gcc ]; then
		if [ ! -f ${GCC_SRC}.patch ]; then
			tar xzf ${WORK_DIR}/${GCC_SRC}.patch.tar.gz || exit 1
		fi
		patch -ruN -p1 -d ${GCC_SRC} < ${GCC_SRC}.patch || exit 1
		cd ${SRC_DIR}/${GCC_SRC}/libstdc++-v3/config/os
		rm -rf newlib
		ln -s qnx/qnx7 newlib
		cd ${SRC_DIR}/${GCC_SRC}/libstdc++-v3 && autoreconf -f || exit 1
		echo `date` > ${WORK_DIR}/have-patched-gcc
	fi
}
# ----------------------------------------

# BINUTILS:

doConfig_binutils() {
	echo "Configuring binutils..."

	BUILD_DIR="${SRC_DIR}/build-${BINUTILS_SRC}"

	# reconfigure means clean build
	if [ -d ${BUILD_DIR} ]; then
		rm -rf ${BUILD_DIR}
	fi

	mkdir ${BUILD_DIR}

	cd ${BUILD_DIR}

	#--program-prefix=bb10- \
	#--program-suffix="-${binutils_ver}" \
	#--enable-host-shared \
	#--host="${QNX_ABI}" \

	../${BINUTILS_SRC}/configure \
		--srcdir="../${BINUTILS_SRC}" \
		--build="${HOST_SYSTEM}" \
		--target="${QNX_ABI}" \
		--prefix="${PREFIX}" \
		--libdir="${QNX_PREBUILT_LIBEXEC}" \
		--libexecdir="${QNX_PREBUILT_LIBEXEC}" \
		--enable-version-specific-runtime-libs \
		--with-local-prefix="${APP_ROOT}" \
		--with-build-sysroot="${APP_ROOT}" \
		--enable-threads=posix \
		--enable-shared \
		--disable-werror \
		--disable-nls \
		--disable-tls \
		--disable-libssp \
		--with-bugurl="${BUGURL}" \
		--enable-lto \
		--enable-shared \
		--enable-gold=yes \
		--with-newlib \
		CFLAGS="-pipe" \
		CXXFLAGS="-pipe" \
		|| exit 1
}
# ----------------------------------------
# GCC:

doConfig_gcc() {
	echo "Configuring gcc..."
	
	BUILD_DIR="${SRC_DIR}/build-${GCC_SRC}"

	# reconfigure means clean build
	if [ -d ${BUILD_DIR} ]; then
		rm -rf ${BUILD_DIR}
	fi

	mkdir ${BUILD_DIR}

	cd ${BUILD_DIR}

	#--program-prefix=bb10- \
	#--program-suffix="-${gcc_ver}" \
	#--enable-host-shared \
	#--with-multilib-list=armv7-a \
	#--with-native-system-headers="${QNX_INC}" \
  #--enable-cheaders=c \
	#--enable-multilib \
	#--with-multilib-list=armv7-a,armv8-a \
	#--enable-symvers=gnu-versioned-namespace \

	../${GCC_SRC}/configure \
		--srcdir=../${GCC_SRC} \
		--build="${HOST_SYSTEM}" \
		--target="${QNX_ABI}" \
		--prefix="${PREFIX}" \
		--libdir="${QNX_PREBUILT_LIBEXEC}" \
		--libexecdir="${QNX_PREBUILT_LIBEXEC}" \
		--enable-version-specific-runtime-libs \
		--with-local-prefix="${APP_ROOT}" \
		--with-build-sysroot="${APP_ROOT}" \
		--enable-libstdcxx-pch \
		--enable-languages=c,c++ \
		--with-gxx-include-dir="${QNX_INC}/libstdc++/${gcc_ver}" \
		--with-default-libstdcxx-abi=gcc4-compatible \
		--enable-initfini-array \
		--enable-threads=posix \
		--enable-libstdcxx-threads \
		--enable-libstdcxx-filesystem-ts \
		--enable-shared \
		--with-arch=armv7-a \
		--with-float=softfp \
		--with-fpu=neon-vfpv3 \
		--with-mode=thumb \
		--with-endian=little \
		--enable-default-pie \
		--enable-__cxa_atexit \
		--enable-stack-protector \
		--disable-werror \
		--disable-nls \
		--disable-tls \
		--disable-libssp \
		--with-bugurl="${BUGURL}" \
		--enable-lto \
		--disable-bootstrap \
    --with-newlib \
		CFLAGS="-pipe" \
		CXXFLAGS="-pipe" \
		|| exit 1

	echo `date` > ${WORK_DIR}/have-configured-gcc
}

doMake() {
	BUILD_DIR="${SRC_DIR}/build-${BUILD_SRC}"
 
	if [ ! -d ${BUILD_DIR} ]; then
		echo "Configure new build for ${BUILD_SRC}."

		if [ ${BUILD_SRC} = ${BINUTILS_SRC} ]; then
			doConfig_binutils
		elif [ ${BUILD_SRC} = ${GCC_SRC} ]; then
			doConfig_gcc
		fi
	fi

	cd ${BUILD_DIR}
	#
	make -j${HOST_CPU_COUNT} ${MAKE_TARGET} || exit 1
		#2> >(tee ${WORK_DIR}/${BUILD_SRC}-errors.txt) || exit 1

	echo `date` > ${WORK_DIR}/have-built-${BUILD_SRC}
	echo "Finished ${BUILD_STAGE} ${MAKE_TARGET}."
}

doUninstall() {
	if [ -d ${QNX_TARGET} ]; then
		echo "Deleting old installation..."
		rm -rf ${QNX_TARGET}
	fi
}

usage() {
	echo "Usage: build.sh [tool] [clean|configure|build|install]"
	echo "tool: binutils, gcc, libgcc, libstdc++, all, uninstall"
	echo "'$0 all [target]' will install binutils because it is the base toolkit"
}

doPrep
doPatch

case $1 in
all | binutils)
	BUILD_STAGE="$1"
	;;
gcc | libgcc | libstdc++)
	BUILD_STAGE="gcc"
	BUILD_VER="$1"
	;;
uninstall)
	doUninstall
	exit 0
	;;
*)
	usage
	;;
esac

case $2 in
	clean) # set at top for "easy" targets below
		MAKE_TARGET="clean"
		echo "Removing $1 build folders"
		case ${BUILD_STAGE} in
			all)
				rm -f ${WORK_DIR}/have-built-binutils
				rm -f ${WORK_DIR}/have-built-gcc
				rm -rf ${SRC_DIR}/build-${BINUTILS_SRC}
				rm -rf ${SRC_DIR}/build-${GCC_SRC}
			;;
			binutils)
				rm -f ${WORK_DIR}/have-built-binutils
				rm -rf ${SRC_DIR}/build-${BINUTILS_SRC}
			;;
			gcc)
				BUILD_SRC="${GCC_SRC}"
				case ${BUILD_VER} in
					gcc)
					rm -f ${WORK_DIR}/have-built-gcc
					rm -rf ${SRC_DIR}/build-${GCC_SRC}
					;;
					libgcc)
						rm -f ${WORK_DIR}/have-built-gcc
						MAKE_TARGET="clean-target-libgcc"
						doMake
					;;
					libstdc++)
						rm -f ${WORK_DIR}/have-built-gcc
						MAKE_TARGET="clean-target-libstdc++-v3"
						doMake
					;;
				esac
			;;
		esac
	;;
	configure)
			echo "Configuring $1..."
		case ${BUILD_STAGE} in
			all)
			rm -f ${WORK_DIR}/have-built-binutils
			rm -f ${WORK_DIR}/have-built-gcc
				doConfig_binutils
				doConfig_gcc
				;;
			binutils)
			rm -f ${WORK_DIR}/have-built-binutils
				doConfig_binutils
			;;
			gcc)
				rm -f ${WORK_DIR}/have-built-gcc
				doConfig_gcc
			;;
		esac
	;;
	build)
		echo "Building $1..."
		case ${BUILD_STAGE} in
			all)
				rm -f ${WORK_DIR}/have-built-binutils
				rm -f ${WORK_DIR}/have-built-gcc
				MAKE_TARGET="all"
				BUILD_SRC="${BINUTILS_SRC}"
				doMake
				MAKE_TARGET="install"
				doMake
				BUILD_SRC="${GCC_SRC}"
				MAKE_TARGET="all"
				doMake
				;;
			binutils)
				rm -f ${WORK_DIR}/have-built-binutils
				BUILD_SRC="${BINUTILS_SRC}"
				doMake
			;;
			gcc)
				if [ ! -f have-built-binutils ]; then
					BUILD_SRC="${BINUTILS_SRC}"
					MAKE_TARGET="all"
					doMake
				fi
				rm -f have-built-gcc
				BUILD_SRC="${GCC_SRC}"
				case ${BUILD_VER} in
					gcc)
						MAKE_TARGET="all-gcc"
						doMake
					;;
					libgcc)
						MAKE_TARGET="all-target-libgcc"
						doMake
					;;
					libstdc++)
						MAKE_TARGET="all-target-libstdc++-v3"
						doMake
					;;
				esac
			;;
		esac
	;;
	install)
		case ${BUILD_STAGE} in
			all)
				BUILD_SRC="${BINUTILS_SRC}"
				MAKE_TARGET="all"
				[ -f have-built-binutils ] || doMake
				MAKE_TARGET="install"
				doMake
				BUILD_SRC="${GCC_SRC}"
				MAKE_TARGET="all"
				[ -f have-built-gcc ] || doMake
				MAKE_TARGET="install"
				doMake
			;;
			binutils)
				BUILD_SRC="${BINUTILS_SRC}"
				MAKE_TARGET="all"
				[ -f have-built-binutils ] || doMake
				MAKE_TARGET="install"
				doMake
			;;
			gcc)
				BUILD_SRC="${GCC_SRC}"
				case ${BUILD_VER} in
					gcc)
						MAKE_TARGET="all-gcc"
						[ -f have-built-${MAKE_TARGET} ] || doMake
						MAKE_TARGET="install-gcc"
						doMake
					;;
					libgcc)
						MAKE_TARGET="all-target-libgcc"
            [ -f have-built-${MAKE_TARGET} ] || doMake
						MAKE_TARGET="install-target-libgcc"
						doMake
					;;
					libstdc++)
						MAKE_TARGET="all-target-libstdc++-v3"
						[ -f have-built-${MAKE_TARGET} ] || doMake
						MAKE_TARGET="install-target-libstdc++-v3"
						doMake
					;;
				esac
			;;
		esac
	;;
	*)
		usage
	;;
esac

