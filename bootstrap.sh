#!/bin/bash
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -x # be verbose about what we're doing for now

DIR=`pwd`
PATHO=$PATH
CROSSDIR="$DIR/cc"  # crosstools dir


BUILDARCHS="x86_64-pc-elf" # x86_64-pc-elf i686-pc-elf aarch64-none-elf
BUILDTARGET="" # target to build
while getopts "a:" opt; do
	case "$opt" in
		a)
			BUILDARCHS=${OPTARG,,}
		;;
	esac
done


# simple checks
TOOLS="curl git bison flex make gcc gpp texindex gdb nasm tar xzcat python patch"
for TOOL in $TOOLS; do
	if ! which "$TOOL"; then
		echo "$TOOL not found; exiting"
		exit -1;
	fi
done


if ! test -f "$CROSSDIR/bin/"; then
	mkdir -p "$CROSSDIR"
	mkdir -p "$CROSSDIR/bin/"
fi

# check for cross compile tools
for BUILDARCH in $BUILDARCHS; do
	LD="$CROSSDIR/bin/$BUILDARCH-ld"
	GCC="$CROSSDIR/bin/$BUILDARCH-gcc"
	LDC="$CROSSDIR/bin/ldc2"
	BOCHS="$CROSSDIR/bin/bochs"

	if ! test -f "$LD"; then
		BINSRCDIR="$CROSSDIR/binutils-2.24"
		BINARCHIVE="$CROSSDIR/binutils-2.24.tar.bz2"
		BINBUILD="$CROSSDIR/binutils-2.24-$BUILDARCH"

		# fetch binutils
		if ! test -d "$BINSRCDIR"; then
			test -f "$BINARCHIVE" || curl -o "$BINARCHIVE" "http://ftp.gnu.org/gnu/binutils/binutils-2.24.tar.bz2"
			tar -xjf "$BINARCHIVE" -C "$CROSSDIR"
			rm -rf "$BINARCHIVE"
		fi

		mkdir -p "$BINBUILD"
		export PREFIX="$CROSSDIR"
		export TARGET="$BUILDARCH"

		cd "$BINBUILD"
		make clean
		../binutils-2.24/configure --target="$BUILDARCH" --prefix="$CROSSDIR" --disable-nls --enable-64-bit-bfd # can we do this here?
		make all
		make install
	fi

	if ! test -f "$GCC"; then
		GCCSRCDIR="$CROSSDIR/gcc-4.8.2"
		GCCARCHIVE="$CROSSDIR/gcc-4.8.2.tar.bz2"
		GCCBUILD="$CROSSDIR/gcc-4.8.2-$BUILDARCH"

		# fetch gcc
		if ! test -d "$GCCSRCDIR"; then
			test -f "$GCCARCHIVE" || curl -o "$GCCARCHIVE" "ftp://ftp.gnu.org/gnu/gcc/gcc-4.8.2/gcc-4.8.2.tar.bz2"
			tar -xjf "$GCCARCHIVE" -C "$CROSSDIR"
			rm -rf "$GCCARCHIVE"
		fi

		# fetch iconv
		if ! test -d "$GCCSRCDIR/iconv"; then
			curl -o "$GCCSRCDIR/libiconv-1.14.tar.gz" "http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz"
			tar -xzf "$GCCSRCDIR/libiconv-1.14.tar.gz" -C "$GCCSRCDIR"
			mv "$GCCSRCDIR/libiconv-1.14" "$GCCSRCDIR/iconv"
			rm "$GCCSRCDIR/libiconv-1.14.tar.gz"
		fi

		# fetch gmp
		if ! test -d "$GCCSRCDIR/gmp"; then
			curl -o "$GCCSRCDIR/gmp-5.1.3.tar.bz2" "ftp://ftp.gmplib.org/pub/gmp-5.1.3/gmp-5.1.3.tar.bz2"
			tar -xjf "$GCCSRCDIR/gmp-5.1.3.tar.bz2" -C "$GCCSRCDIR"
			mv "$GCCSRCDIR/gmp-5.1.3" "$GCCSRCDIR/gmp"
			rm "$GCCSRCDIR/gmp-5.1.3.tar.bz2"
		fi
	
		# fetch mpfr
		if ! test -d "$GCCSRCDIR/mpfr"; then
			curl -o "$GCCSRCDIR/mpfr-3.1.2.tar.bz2" "http://www.mpfr.org/mpfr-current/mpfr-3.1.2.tar.bz2"
			tar -xjf "$GCCSRCDIR/mpfr-3.1.2.tar.bz2" -C "$GCCSRCDIR"
			mv "$GCCSRCDIR/mpfr-3.1.2" "$GCCSRCDIR/mpfr"
			rm "$GCCSRCDIR/mpfr-3.1.2.tar.bz2"
		fi

		# fetch mpc
		if ! test -d "$GCCSRCDIR/mpc"; then
			curl -o "$GCCSRCDIR/mpc-1.0.1.tar.gz" "http://www.multiprecision.org/mpc/download/mpc-1.0.1.tar.gz"
			tar -xzf "$GCCSRCDIR/mpc-1.0.1.tar.gz" -C "$GCCSRCDIR"
			mv "$GCCSRCDIR/mpc-1.0.1" "$GCCSRCDIR/mpc"
			rm "$GCCSRCDIR/mpc-1.0.1.tar.gz"
		fi

		# fetch gdc
		if ! test -d "$CROSSDIR/gdc/dev"; then
			mkdir -p "$CROSSDIR/gdc"
			cd "$CROSSDIR"
			git clone https://github.com/D-Programming-GDC/GDC.git "$CROSSDIR/gdc/dev"
			cd "$CROSSDIR/gdc/dev"
			git checkout gdc-4.8
			$CROSSDIR/gdc/dev/setup-gcc.sh "$GCCSRCDIR"
		fi


		mkdir -p "$GCCBUILD"
		export PREFIX="$CROSSDIR"
		export TARGET="$BUILDARCH"
		export PATH="$CROSSDIR/bin:$PATHO:$CROSSDIR/bin"

		cd "$GCCBUILD"
		make clean
		../gcc-4.8.2/configure --target="$BUILDARCH" --prefix="$CROSSDIR" --disable-nls --enable-languages=c,c++,d --without-headers --disable-libphobos
		make all-gcc
		make install-gcc
	fi


	if ! test -f "$LDC"; then
		LDCBUILD="$CROSSDIR/ldc/build-$BUILDARCH"

		cd "$CROSSDIR"
		test -d "$CROSSDIR/ldc" || git clone --recursive https://github.com/ldc-developers/ldc.git

		mkdir -p "$LDCBUILD"
		export PREFIX="$CROSSDIR"
		export TARGET="$BUILDARCH"
		export PATH="$CROSSDIR/bin:$PATHO:$CROSSDIR/bin"
		cd "$LDCBUILD"

		make clean 
		cmake .. -DCMAKE_INSTALL_PREFIX="$CROSSDIR" -DINCLUDE_INSTALL_DIR="$CROSSDIR/include"
		make
		make install
	fi


	if ! test -f "$BOCHS"; then
		cd "$CROSSDIR"
		test -f "$CROSSDIR/bochs-2.6.2.tar.gz" || curl -o "$CROSSDIR/bochs-2.6.2.tar.gz" -L http://downloads.sourceforge.net/project/bochs/bochs/2.6.2/bochs-2.6.2.tar.gz

		test -d "$CROSSDIR/bochs-2.6.2" || tar -xzf "$CROSSDIR/bochs-2.6.2.tar.gz" -C "$CROSSDIR"
		
		cd "$CROSSDIR/bochs-2.6.2"
		patch -p1 < ../../support/bochs.patch
		./configure --enable-smp --enable-cpu-level=6 --enable-all-optimizations --enable-x86-64 --enable-pci --enable-vmx --enable-debugger --enable-disasm --enable-debugger-gui --enable-logging --enable-fpu --enable-3dnow --enable-sb16=dummy --enable-cdrom --enable-x86-debugger --enable-iodebug --disable-plugins --disable-docbook --with-x --with-x11 --with-term --enable-ne2000 --enable-large-ramfile --enable-pae --enable-4meg-pages --prefix="$CROSSDIR"

		make
		make install
	fi
done

# clean build tools dir
rm -rf $CROSSDIR/binutils-*
rm -rf $CROSSDIR/gcc-*
rm -rf $CROSSDIR/gdc
rm -rf $CROSSDIR/ldc
rm -rf $CROSSDIR/bochs-*

cd "$DIR"

# fetch waf
if ! test -f "waf"; then
	curl -o "$DIR/waf" "http://waf.googlecode.com/files/waf-1.7.13"
	chmod a+rx "$DIR/waf"
fi