#!/bin/sh

[ -z "${WORK_DIR}" ] && echo "Please set WORK_DIR" && exit 1
[ -z "${SRC_DIR}" ] && echo "Please set SRC_DIR" && exit 1
[ -z "${DIST_DIR}" ] && echo "Please set DIST_DIR" && exit 1
mkdir -p ${WORK_DIR} ${DIST_DIR} ${SRC_DIR}

BUGURL="didacticode.ca/contact"

binutils_ver="2.35"
BINUTILS_SRC="binutils-${binutils_ver}"

gcc_ver="9.3.0"
GCC_SRC="gcc-${gcc_ver}"

gmp_ver="6.1.0"
isl_ver="0.18"
mpc_ver="1.0.3"
mpfr_ver="3.1.4"

# gmp doesn't not have gz version
GCC_URL="https://ftp.gnu.org/pub/gnu"
CONTRIB_URL="ftp://gcc.gnu.org/pub/gcc/infrastructure"

DOWNLOAD_CMD="wget"

doDownload() {
	echo "Downloading sources..."
	mkdir -p ${DIST_DIR}
	cd ${DIST_DIR}
	
	for src in binutils gcc ; do
		file=`eval echo ${src}-$\{${src}_ver\}`

		([ -f ${file}.tar.gz ] || [ -f ${file}.tar.bz2 ]) \
		|| (${DOWNLOAD_CMD} ${GCC_URL}/${src}/${file}/${file}.tar.gz \
		|| ${DOWNLOAD_CMD} ${GCC_URL}/${src}/${file}.tar.bz2) \
		|| exit 1
	done
		
	for src in mpc gmp mpfr isl; do
		file=`eval echo ${src}-$\{${src}_ver\}`

		([ -f ${file}.tar.gz ] || [ -f ${file}.tar.bz2 ]) \
		|| (${DOWNLOAD_CMD} ${CONTRIB_URL}/${file}.tar.gz \
		|| ${DOWNLOAD_CMD} ${CONTRIB_URL}/${file}.tar.bz2) \
		|| exit 1
	done
}

doExtract() {
	doDownload
	cd ${SRC_DIR}

	echo "Extracting binutils..."
	[ -d ${BINUTILS_SRC} ] \
		|| ([ -f ${DIST_DIR}/${BINUTILS_SRC}.tar.gz ] \
			&& tar xzf ${DIST_DIR}/${BINUTILS_SRC}.tar.gz) \
		|| ([ -f ${DIST_DIR}/${BINUTILS_SRC}.tar.bz2 ] \
			&& tar xjf ${DIST_DIR}/${BINUTILS_SRC}.tar.bz2) \
		|| exit 1

	echo "Extracting gcc..."
	[ -d ${GCC_SRC} ] \
		|| ([ -f ${DIST_DIR}/${GCC_SRC}.tar.gz ] \
			&& tar xzf ${DIST_DIR}/${GCC_SRC}.tar.gz) \
		|| ([ -f ${DIST_DIR}/${GCC_SRC}.tar.bz2 ] \
			&& tar xjf ${DIST_DIR}/${GCC_SRC}.tar.bz2) \
		|| exit 1

	for src in mpc gmp mpfr isl; do
		file=`eval echo ${src}-$\{${src}_ver\}`
		([ -f ${DIST_DIR}/${src}-${file}.tar.gz ] \
			&& ln -s ${DIST_DIR}/${src}-${file}.tar.gz ${SRC_DIR}/${GCC_SRC}) \
		|| ([ -f ${DIST_DIR}/${src}-${file}.tar.bz2 ] \
			&& ln -s ${DIST_DIR}/${src}-${file}.tar.bz2 ${SRC_DIR}/${GCC_SRC}) \
	done
	
	cd ${SRC_DIR}/${GCC_SRC} && ./contrib/download_prerequisites || exit
	cd ${SRC_DIR}
}
