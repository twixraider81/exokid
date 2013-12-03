TARGET		:= x86_64-pc-elf
#TARGET		:= i686-pc-elf
#TARGET		:= aarch64-none-elf

QUIET		:= @
DIR			:= $(shell pwd)/../
CROSSDIR	:= $(DIR)cross-$(TARGET)/

BINUTILS		:= binutils-2.24.51
BINUTILSARCHIVE := $(BINUTILS).tar.bz2
BINUTILSURL		:= ftp://sourceware.org/pub/binutils/snapshots/$(BINUTILSARCHIVE)
GCC				:= gcc-4.8.2
GCCARCHIVE		:= $(GCC).tar.bz2
GCCURL			:= ftp://ftp.gnu.org/gnu/gcc/gcc-4.8.2/$(GCCARCHIVE)
ICONV			:= libiconv-1.14
ICONVARCHIVE	:= $(ICONV).tar.gz
ICONVURL		:= http://ftp.gnu.org/pub/gnu/libiconv/$(ICONVARCHIVE)
GMP				:= gmp-5.1.3
GMPARCHIVE		:= $(GMP).tar.bz2
GMPURL			:= ftp://ftp.gmplib.org/pub/gmp-5.1.3/$(GMPARCHIVE)
MPFR			:= mpfr-3.1.2
MPFRARCHIVE		:= $(MPFR).tar.bz2
MPFRURL			:=  http://www.mpfr.org/mpfr-current/$(MPFRARCHIVE)
MPC				:= mpc-1.0.1
MPCARCHIVE		:= $(MPC).tar.gz
MPCURL			:=  http://www.multiprecision.org/mpc/download/$(MPCARCHIVE)
YASMBUILD		:= yasm-1.2.0
YASMARCHIVE		:= $(YASMBUILD).tar.gz
YASMURL			:= http://www.tortall.net/projects/yasm/releases/$(YASMARCHIVE)
LDCURL			:= https://github.com/ldc-developers/ldc.git
GDCURL			:= https://github.com/D-Programming-GDC/GDC.git

help:
	$(QUIET)echo "\nUsing: $(CROSSDIR)\n\nPlease choose:\n- debian: apt-get install dependencies on debian\n- cross-tools: build binutils, gcc, gdc2 and ldc2\n- cross-binutils: build $(BINUTILS)\n- cross-gcc: build $(GCC)\n- cross-gdc: build GDC\n- cross-ldc: build LDC2\n- yasm: build $(YASMBUILD)\n- bochs: build bochs"

debian:
	$(QUIET)if test ! -x /usr/bin/apt-get ; then \
		echo "apt-get unavailable"; \
		exit 1; \
	fi
	$(QUIET)apt-get install grub2 build-essential bison flex curl gpp gcc-multilib g++-multilib libgmp3-dev libmpc-dev libmpfr-dev texinfo git cmake libcurl4-openssl-dev llvm clang libconfig++ libconfig-dev qemu libgtk2.0-dev gdb xz-utils ninja nasm sudo libdevmapper-dev liblzma-dev libfuse-dev;

cross-tools: cross-binutils cross-gcc cross-gdc cross-ldc

cross-binutils:
	mkdir -p $(CROSSDIR); \
	test -f $(CROSSDIR)$(BINUTILSARCHIVE) || curl -o $(CROSSDIR)$(BINUTILSARCHIVE) $(BINUTILSURL); \
	test -d $(CROSSDIR)$(BINUTILS) || tar -xjf $(CROSSDIR)$(BINUTILSARCHIVE) -C $(CROSSDIR); \
	mkdir -p $(CROSSDIR)binutils-build; \
	export PREFIX=$(CROSSDIR); export TARGET=$(TARGET); cd $(CROSSDIR)binutils-build; $(CROSSDIR)$(BINUTILS)/configure --target=$(TARGET) --prefix="$(CROSSDIR)" --disable-nls --enable-64-bit-bfd; make all install; \

cross-gcc:
	mkdir -p $(CROSSDIR); \
	test -f $(CROSSDIR)$(GCCARCHIVE) || curl -o $(CROSSDIR)$(GCCARCHIVE) $(GCCURL); \
	test -f $(CROSSDIR)$(ICONVARCHIVE) || curl -o $(CROSSDIR)$(ICONVARCHIVE) $(ICONVURL); \
	test -f $(CROSSDIR)$(GMPARCHIVE) || curl -o $(CROSSDIR)$(GMPARCHIVE) $(GMPURL); \
	test -f $(CROSSDIR)$(MPFRARCHIVE) || curl -o $(CROSSDIR)$(MPFRARCHIVE) $(MPFRURL); \
	test -f $(CROSSDIR)$(MPCARCHIVE) || curl -o $(CROSSDIR)$(MPCARCHIVE) $(MPCURL); \
	test -d $(CROSSDIR)$(MPC) || tar -xzf $(CROSSDIR)$(MPCARCHIVE) -C $(CROSSDIR); \
	test -d $(CROSSDIR)$(MPFR) || tar -xjf $(CROSSDIR)$(MPFRARCHIVE) -C $(CROSSDIR); \
	test -d $(CROSSDIR)$(GMP) || tar -xjf $(CROSSDIR)$(GMPARCHIVE) -C $(CROSSDIR); \
	test -d $(CROSSDIR)$(ICONV) || tar -xzf $(CROSSDIR)$(ICONVARCHIVE) -C $(CROSSDIR); \
	test -d $(CROSSDIR)$(GCC) || tar -xjf $(CROSSDIR)$(GCCARCHIVE) -C $(CROSSDIR); \
	test -d $(CROSSDIR)$(GCC)/iconv || mv $(CROSSDIR)$(ICONV) $(CROSSDIR)$(GCC)/iconv; \
	test -d $(CROSSDIR)$(GCC)/gmp || mv $(CROSSDIR)$(GMP) $(CROSSDIR)$(GCC)/gmp; \
	test -d $(CROSSDIR)$(GCC)/mpfr || mv $(CROSSDIR)$(MPFR) $(CROSSDIR)$(GCC)/mpfr; \
	test -d $(CROSSDIR)$(GCC)/mpc || mv $(CROSSDIR)$(MPC) $(CROSSDIR)$(GCC)/mpc; \
	mkdir -p $(CROSSDIR)gcc-build; \
	export PREFIX=$(CROSSDIR); \
	export TARGET=$(TARGET); \
	export PATH=$$PATH:$$PREFIX/bin; \
	cd $(CROSSDIR)gcc-build; \
	$(CROSSDIR)$(GCC)/configure --target=$(TARGET) --prefix="$(CROSSDIR)" --disable-nls --enable-languages=c,c++ --without-headers; \
	make all-gcc; \
	make install-gcc; \

cross-gdc:
	mkdir -p $(CROSSDIR); \
	mkdir -p $(CROSSDIR)gdc; \
	mkdir -p $(CROSSDIR)gdc/dev; \
	cd $(CROSSDIR); \
	git clone $(GDCURL) gdc/dev; \
	cd $(CROSSDIR)gdc/dev; \
	git checkout gdc-4.8; \
	$(CROSSDIR)gdc/dev/setup-gcc.sh $(CROSSDIR)$(GCC); \
	export PREFIX=$(CROSSDIR); \
	export TARGET=$(TARGET); \
	export PATH=$$PATH:$$PREFIX/bin; \
	mkdir -p $(CROSSDIR)gcc-build; \
	cd $(CROSSDIR)gcc-build; \
	make clean; \
	$(CROSSDIR)$(GCC)/configure --target=$(TARGET) --prefix="$(CROSSDIR)" --disable-nls --enable-languages=c,c++,d --without-headers --disable-libphobos; \
	make all-gcc; \
	make install-gcc; \

cross-ldc:
	mkdir -p $(CROSSDIR); \
	cd $(CROSSDIR); \
	test -d $(CROSSDIR)ldc || git clone --recursive $(LDCURL); \
	test -d $(CROSSDIR)ldc/build || mkdir $(CROSSDIR)ldc/build; \
	cd $(CROSSDIR)ldc/build; \
	export PREFIX=$(CROSSDIR); \
	export TARGET=$(TARGET); \
	export PATH=$$PATH:$$PREFIX/bin; \
	cmake .. -DCMAKE_INSTALL_PREFIX=$(CROSSDIR) -DINCLUDE_INSTALL_DIR=$(CROSSDIR)include; \
	make; \
	make install; \

yasm:
	mkdir -p $(CROSSDIR); \
	test -f $(CROSSDIR)$(YASMARCHIVE) || curl -o $(CROSSDIR)$(YASMARCHIVE) $(YASMURL); \
	test -d $(CROSSDIR)$(YASMBUILD) || tar -xzf $(CROSSDIR)$(YASMARCHIVE) -C $(CROSSDIR); \
	cd $(CROSSDIR)$(YASMBUILD); \
	export PREFIX=$(CROSSDIR); \
	export TARGET=$(TARGET); \
	export PATH=$$PATH:$$PREFIX/bin; \
	./configure --target=$(TARGET) --prefix="$(CROSSDIR)" --disable-nls ; \
	make; \
	make install; \

bochs:
	cd $(CROSSDIR); \
	test -f $(CROSSDIR)bochs-2.6.2.tar.gz || curl -o $(CROSSDIR)bochs-2.6.2.tar.gz http://downloads.sourceforge.net/project/bochs/bochs/2.6.2/bochs-2.6.2.tar.gz
	test -d $(CROSSDIR)bochs-2.6.2 || tar -xzf $(CROSSDIR)bochs-2.6.2.tar.gz -C $(CROSSDIR)
	cd $(CROSSDIR)bochs-2.6.2; ./configure --enable-smp --enable-cpu-level=6 --enable-all-optimizations --enable-x86-64 --enable-pci --enable-vmx --enable-debugger --enable-disasm --enable-debugger-gui --enable-logging --enable-fpu --enable-3dnow --enable-sb16=dummy --enable-cdrom --enable-x86-debugger --enable-iodebug --disable-plugins --disable-docbook --with-x --with-x11 --with-term --enable-ne2000 --enable-large-ramfile --enable-pae --enable-4meg-pages --prefix=$(CROSSDIR); \
	make; make install

.PHONY: help debian cross-tools cross-binutils cross-gcc cross-gdc cross-ldc yasm bochs