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

# //FIXME: error checking, proper on configure or half downloaded archives
set -u
set -e

DIR=`pwd`
UNAME=`uname -s | grep -m1 -ioE '[a-z]+' | awk 'NR==1{print $0}'` # detection of OS
CROSSDIR="$DIR/cc/$UNAME" # crosstools dir

WIN=0
BUILDARCHS="x86_64-pc-elf" # x86_64-pc-elf, "x86_64-pc-elf i686-pc-elf aarch64-none-elf"
BUILDBACKENDS="gdc" # gdc, "gdc ldc dmd"
THREADS=`nproc`

while getopts "ckva:b:" opt; do
	case "$opt" in
		a) # select architectures to build
			BUILDARCHS=${OPTARG,,}
		;;
		c) # clean build tools dir
			rm -vrf $CROSSDIR
			rm -vrf $DIR/cc
			rm -vrf $DIR/build
			rm -vrf $DIR/waf
			rm -vrf $DIR/.lock-*
			rm -vrf $DIR/.waf-*
			rm -vrf $DIR/.waf3-*
			exit 0
		;;
		b) # compiler backend to build
			BUILDBACKENDS=${OPTARG,,}
		;;
		t) # set thread count
			THREADS=${OPTARG,,}
		;;
		v) # set verbosity
			set -x
		;;
	esac
done

if [[ "$UNAME" == "CYGWIN" || "$UNAME" == "MINGW" ]]; then
	WIN=1
fi


# mingw will fail
if [ "$UNAME" == "MINGW" ]; then
	echo "mingw not supported; exiting"
	exit 0;
fi

# check for tools
TOOLS="curl git svn bison flex make gcc gdb texindex tar xzcat python patch"
for TOOL in $TOOLS; do
	if ! which "$TOOL"; then
		echo "$TOOL not found; exiting"
		exit 0;
	fi
done

if [[ $BUILDBACKENDS =~ "ldc" ]]; then
	if ! which "cmake"; then
		echo "cmake not found; exiting"
		exit 0;
	fi
fi



if [ ! -f "$CROSSDIR/bin/" ]; then
	mkdir -p "$CROSSDIR"
	mkdir -p "$CROSSDIR/bin/"
fi


# thread count
let THREADS=$THREADS*2+1


# build cross compile tools
for BUILDARCH in $BUILDARCHS; do
	LD="$CROSSDIR/bin/$BUILDARCH-ld"
	GCC="$CROSSDIR/bin/$BUILDARCH-gcc"
	CLANG="$CROSSDIR/bin/clang"
	LDC="$CROSSDIR/bin/ldc2"
	DMD="$CROSSDIR/bin/dmd"
	BOCHS="$CROSSDIR/bin/bochs"

	# binutils
	if [ ! -f "$LD" ]; then
		BINSRCDIR="$CROSSDIR/binutils-2.25"
		BINARCHIVE="$CROSSDIR/binutils-2.25.tar.bz2"
		BINBUILD="$CROSSDIR/binutils-2.25-$BUILDARCH"

		# fetch binutils
		if [ ! -d "$BINSRCDIR" ]; then
			test -f "$BINARCHIVE" || curl -v -o "$BINARCHIVE" "http://ftp.gnu.org/gnu/binutils/binutils-2.25.tar.bz2"
			tar -xjf "$BINARCHIVE" -C "$CROSSDIR"
			rm -f "$BINARCHIVE"
		fi

		mkdir -p "$BINBUILD"
		export PREFIX="$CROSSDIR"
		export TARGET="$BUILDARCH"

		cd "$BINBUILD"
		../binutils-2.25/configure --target="$BUILDARCH" --prefix="$CROSSDIR" --disable-nls --disable-werror

		make -j$THREADS all
		make install
	fi


	# cross gcc
	if [ ! -f "$GCC" ]; then
		GCCSRCDIR="$CROSSDIR/gcc-5.2.0"
		GCCARCHIVE="$CROSSDIR/gcc-5.2.0.tar.bz2"
		GCCBUILD="$CROSSDIR/gcc-5.2.0-$BUILDARCH"

		# fetch gcc
		if [ ! -d "$GCCSRCDIR" ]; then
			test -f "$GCCARCHIVE" || curl -v -o "$GCCARCHIVE" "https://ftp.gnu.org/gnu/gcc/gcc-5.2.0/gcc-5.2.0.tar.bz2"
			tar -xjf "$GCCARCHIVE" -C "$CROSSDIR"
			rm -f "$GCCARCHIVE"
		fi

		# fetch iconv
		if [ ! -d "$GCCSRCDIR/iconv" ]; then
			curl -v -o "$GCCSRCDIR/libiconv-1.14.tar.gz" "http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz"
			tar -xzf "$GCCSRCDIR/libiconv-1.14.tar.gz" -C "$GCCSRCDIR"
			mv "$GCCSRCDIR/libiconv-1.14" "$GCCSRCDIR/iconv"
			rm "$GCCSRCDIR/libiconv-1.14.tar.gz"
		fi

		# fetch gmp
		if [ ! -d "$GCCSRCDIR/gmp" ]; then
			curl -v -o "$GCCSRCDIR/gmp-6.0.0a.tar.bz2" "https://gmplib.org/download/gmp/gmp-6.0.0a.tar.bz2"
			tar -xjf "$GCCSRCDIR/gmp-6.0.0a.tar.bz2" -C "$GCCSRCDIR"
			mv "$GCCSRCDIR/gmp-6.0.0" "$GCCSRCDIR/gmp"
			rm "$GCCSRCDIR/gmp-6.0.0a.tar.bz2"
		fi
	
		# fetch mpfr
		if [ ! -d "$GCCSRCDIR/mpfr" ]; then
			curl -v -o "$GCCSRCDIR/mpfr-3.1.3.tar.bz2" "http://www.mpfr.org/mpfr-current/mpfr-3.1.3.tar.bz2"
			tar -xjf "$GCCSRCDIR/mpfr-3.1.3.tar.bz2" -C "$GCCSRCDIR"
			mv "$GCCSRCDIR/mpfr-3.1.3" "$GCCSRCDIR/mpfr"
			rm "$GCCSRCDIR/mpfr-3.1.3.tar.bz2"
		fi

		# fetch mpc
		if [ ! -d "$GCCSRCDIR/mpc" ]; then
			curl -v -o "$GCCSRCDIR/mpc-1.0.3.tar.gz" "http://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz"
			tar -xzf "$GCCSRCDIR/mpc-1.0.3.tar.gz" -C "$GCCSRCDIR"
			mv "$GCCSRCDIR/mpc-1.0.3" "$GCCSRCDIR/mpc"
			rm "$GCCSRCDIR/mpc-1.0.3.tar.gz"
		fi

		# fetch isl
		if [ ! -d "$GCCSRCDIR/isl" ]; then
			curl -v -o "$GCCSRCDIR/isl-0.14.tar.bz2" "ftp://gcc.gnu.org/pub/gcc/infrastructure/isl-0.14.tar.bz2"
			tar -xjf "$GCCSRCDIR/isl-0.14.tar.bz2" -C "$GCCSRCDIR"
			mv "$GCCSRCDIR/isl-0.14" "$GCCSRCDIR/isl"
			rm "$GCCSRCDIR/isl-0.14.tar.bz2"
		fi

		# fetch cloog
		if [ ! -d "$GCCSRCDIR/cloog" ]; then
			curl -v -o "$GCCSRCDIR/cloog-0.18.1.tar.gz" "ftp://gcc.gnu.org/pub/gcc/infrastructure/cloog-0.18.1.tar.gz"
			tar -xzf "$GCCSRCDIR/cloog-0.18.1.tar.gz" -C "$GCCSRCDIR"
			mv "$GCCSRCDIR/cloog-0.18.1" "$GCCSRCDIR/cloog"
			rm "$GCCSRCDIR/cloog-0.18.1.tar.gz"
		fi

		# fetch gdc
		if [[ ! -d "$CROSSDIR/gdc/dev" && $BUILDBACKENDS =~ "gdc" ]]; then
			mkdir -p "$CROSSDIR/gdc"
			cd "$CROSSDIR"
			git clone https://github.com/D-Programming-GDC/GDC.git "$CROSSDIR/gdc/dev"
			cd "$CROSSDIR/gdc/dev"
			git checkout gdc-5
			$CROSSDIR/gdc/dev/setup-gcc.sh "$GCCSRCDIR"
		fi


		# build
		mkdir -p "$GCCBUILD"
		export PREFIX="$CROSSDIR"
		export TARGET="$BUILDARCH"

		cd "$GCCBUILD"
		../gcc-5.2.0/configure --target="$BUILDARCH" --prefix="$CROSSDIR" --disable-nls --disable-werror --enable-languages=c,c++,d --without-headers --disable-libphobos

		make -j$THREADS all-gcc
		make -j$THREADS all-target-libgcc
		make install-gcc
		make install-target-libgcc
	fi


	# ldc and perhaps llvm/clang
	if [[ ! -f "$LDC" && $BUILDBACKENDS =~ "ldc" ]]; then
		cd "$CROSSDIR"
		
		let T=($THREADS-1)/2

		# build clang first, this can take a looong time. and memory.
		if ! which "clang"; then
			if [ ! -f "$CLANG" ]; then
				cd "$CROSSDIR"
				test -d "$CROSSDIR/llvm" || svn co http://llvm.org/svn/llvm-project/llvm/branches/release_37 llvm
				cd "$CROSSDIR/llvm/tools"
				test -d "$CROSSDIR/llvm/tools/clang" || svn co http://llvm.org/svn/llvm-project/cfe/branches/release_37 clang
				cd "$CROSSDIR/llvm/tools/clang/tools"
				test -d "$CROSSDIR/llvm/tools/clang/tools/extra" || svn co http://llvm.org/svn/llvm-project/clang-tools-extra/branches/release_37 extra
				cd "$CROSSDIR/llvm/projects" 
				test -d "$CROSSDIR/llvm/projects/compiler-rt" || svn co http://llvm.org/svn/llvm-project/compiler-rt/branches/release_37 compiler-rt
	
				mkdir -p "$CROSSDIR/llvm-build"
				cd "$CROSSDIR/llvm-build"
				../llvm/configure --prefix="$CROSSDIR" --enable-optimized --enable-debug-symbols --enable-debug-runtime --enable-debug-symbols --enable-keep-symbols --enable-backtraces
	
				make -j$T
				make install
	
				cd "$CROSSDIR"
			fi
		fi

		LDCBUILD="$CROSSDIR/ldc/build-$BUILDARCH"

		test -d "$CROSSDIR/ldc" || git clone --recursive https://github.com/ldc-developers/ldc.git

		mkdir -p "$LDCBUILD"
		export PREFIX="$CROSSDIR"
		export TARGET="$BUILDARCH"

		if ! which "clang"; then
			if [ -f "$CLANG" ]; then
				LLVMCONFIG="$CROSSDIR/bin/llvm-config"
			else
				LLVMCONFIG=`which llvm-config`
			fi
		fi


		cd "$LDCBUILD"

		cmake .. -DLLVM_CONFIG="$LLVMCONFIG" -DCMAKE_INSTALL_PREFIX="$CROSSDIR" -DCONF_INST_DIR="$CROSSDIR/local/etc" -DINCLUDE_INSTALL_DIR="$CROSSDIR/include" -DLLVM_INTRINSIC_TD_PATH=`$LLVMCONFIG --includedir`"/llvm/IR" -L

		make -j$THREADS
		make install
	fi


	# dmd
	if [[ ! -f "$DMD" && $BUILDBACKENDS =~ "dmd" ]]; then
		cd "$CROSSDIR"
		
		if [[ ! -d "$CROSSDIR/dmd" ]]; then
			git clone --recursive https://github.com/D-Programming-Language/dmd.git
			cd "$CROSSDIR/dmd"
			git checkout stable	
		fi

		cd "$CROSSDIR/dmd"

		make -j$THREADS -f posix.mak MODEL=64 TARGET_CPU=X86 AUTO_BOOTSTRAP=1
		cp src/dmd "$CROSSDIR/bin/dmd"
		cp ini/linux/bin64/dmd.conf "$CROSSDIR/bin/dmd.conf"
	fi
done


# bochs
if [[ ! -f "$BOCHS"  && $WIN -eq 0 ]]; then
	cd "$CROSSDIR"
	test -f "$CROSSDIR/bochs-2.6.8.tar.gz" || curl -v -o "$CROSSDIR/bochs-2.6.8.tar.gz" -L http://downloads.sourceforge.net/project/bochs/bochs/2.6.8/bochs-2.6.8.tar.gz

	if [ ! -d "$CROSSDIR/bochs-2.6.8" ]; then
		tar -xzf "$CROSSDIR/bochs-2.6.8.tar.gz" -C "$CROSSDIR"
		rm "$CROSSDIR/bochs-2.6.8.tar.gz"
		cd "$CROSSDIR/bochs-2.6.8"
#		patch -p1 < ../../../support/bochs.patch
	fi

	cd "$CROSSDIR/bochs-2.6.8"
	./configure --disable-plugins --enable-x86-64 --enable-smp --enable-cpu-level=6 --enable-large-ramfile --enable-ne2000 --enable-pci --enable-usb --enable-usb-ohci --enable-e1000 --enable-debugger --enable-disasm --enable-debugger-gui --enable-iodebug --enable-all-optimizations --enable-logging --enable-fpu --enable-vmx --enable-svm --enable-avx --enable-x86-debugger --enable-cdrom --enable-sb16=dummy --disable-docbook --with-x --with-x11 --with-term --prefix="$CROSSDIR"

	make -j$THREADS
	make install
fi


# mtools
MTOOLS="$CROSSDIR/bin/mtools"
if [[ ! -f "$MTOOLS"  ]]; then
	test -f "$CROSSDIR/mtools-4.0.18.tar.bz2" || curl -v -o "$CROSSDIR/mtools-4.0.18.tar.bz2" ftp://ftp.gnu.org/gnu/mtools/mtools-4.0.18.tar.bz2

	if [ ! -d "$CROSSDIR/mtools-4.0.18" ]; then
		tar -xjf "$CROSSDIR/mtools-4.0.18.tar.bz2" -C "$CROSSDIR"
		rm "$CROSSDIR/mtools-4.0.18.tar.bz2"
		cd "$CROSSDIR/mtools-4.0.18"
		#patch -p1 < ../../../support/mtools.patch
	fi

	cd "$CROSSDIR/mtools-4.0.18"

	export PREFIX="$CROSSDIR"
	export TARGET="$BUILDARCH"

	./configure --prefix="$CROSSDIR"

	make -j$THREADS
	make install
fi

# done
cd "$DIR"


# fetch waf
if [ ! -f "waf" ]; then
	curl -v -o "$DIR/waf" "https://waf.io/waf-1.8.14"
	chmod a+rx "$DIR/waf"
fi