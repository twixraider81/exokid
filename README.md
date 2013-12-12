exokid - an EXOkernel In D
==========================
    (In its infancy)

Quickstart
----------
- ./bootstrap.sh -a
- ./waf configure
- ./waf build

Look at ./waf --help for further commands, like
todo, backup, bochs, qemu, gdb, kdbg, eclipse


Building
--------

To start the build process first execute bootstrap.sh. The script will check for
necessary tools and compile a cross compiler toolchain.

- ./bootstrap.sh -a x86_64-pc-elf
- ./bootstrap.sh -c
- -a : cross compiler architecture to build, space sperated, i.e. (x86_64-pc-elf | "x86_64-pc-elf i686-pc-elf aarch64-none-elf")
- -c : force cleanup (delete downloaded folders)
- -k : keep downloaded / configured tools

This will take a serious amount of time (and disk space), please be patient.
The built compiler will reside under ./cc/$SYSTEMTYPE/ (i.e. cc/Linux or cc/CYGWIN or something).
Do not delete this folder.
For Cygwin LDC is disabled, as it only builds with a few manual fixes.
(Clang exception linking & WIN32 defines, configuring libconfig build system etc.)

For LDC your system will need libconfig++-dev (on cygwin configure manually with).
For Bochs you will need libx11-dev & libgtk2.0-dev.

After the bootstrap script completed, go ahead configure & build the source.
- ./waf configure --arch=x64 --compiler=gdc
- ./waf build bochs


Background
----------
We all seek for new challenges from time to time. For me it is to get into OS
development. This project is my first project in D as well as my first lowlevel project,
so please bear with me...


Credits & thanks
----------------
 - To the 2 impressive wikis & forums - http://www.lowlevel.eu/ & http://wiki.osdev.org/
 - James Molloy - http://www.jamesmolloy.co.uk/tutorial_html/index.html
 - Brokenthorn OSDev series http://www.brokenthorn.com/Resources/OSDevIndex.html
 - Digital Mars and everything D - http://dlang.org/ & https://github.com/D-Programming-Language
 - The GDC creators - https://github.com/D-Programming-GDC/GDC/
 - The LDC creators - https://github.com/ldc-developers/ldc/
 - XOmB Exokernel - https://www.xomb.org/
 - Arc Kernel - https://github.com/grahamedgecombe/arc/
 - GNU - https://www.gnu.org/
 - Linux - https://www.kernel.org/
 - NetBSD - https://www.netbsd.org/
 - waf - https://code.google.com/p/waf/
 - Eclipse Foundation - https://www.eclipse.org/
 - EFF - https://www.eff.org
