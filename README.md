exokid - an EXOkernel In D
==========================
Quickstart
----------
- ./bootstrap.sh -a x86_64-pc-elf
- ./waf configure --arch=x64 --compiler=gdc
- ./waf build -j4

Look at ./waf --help for further commands, like
todo, backup, bochs, qemu, gdb, kdbg

Building
--------

To start the build process first execute bootstrap.sh.

The script can be controlled via:
	-a (x86_64-pc-elf|"x86_64-pc-elf i686-pc-elf aarch64-none-elf")
The bootstrap script will check for necessary tools and compile a cross compiler
toolchain.

This will take a serious amount of time (and disk space), please be patient.
The built compiler will reside under ./cc/, so don't delete this folder.
For LDC you will need libconfig++-dev. For Bochs you will need libx11-dev & libgtk2.0-dev.

After that completed configure & build the source.
./waf configure --compiler=gdc --arch=x64
./waf build


Background
----------
We all seek for new challenges from time to time. For me it is to get into OS
development. This project is my first project in D as well as my first lowlevel project,
so please bear with me...


Credits & thanks
----------------
 - To the 2 impressive wikis & forums - http://www.lowlevel.eu & http://wiki.osdev.org
 - James Molloy - http://www.jamesmolloy.co.uk/tutorial_html/index.html
 - Brokenthorn OSDev series http://www.brokenthorn.com/Resources/OSDevIndex.html
 - Digital Mars and everything druntime http://dlang.org/
 - The GDC creators - https://github.com/D-Programming-GDC/GDC
 - The LDC creators - https://github.com/ldc-developers/ldc
 - XOmB Exokernel - http://www.xomb.org/
 - Arc Kernel - https://github.com/grahamedgecombe/arc
 - Linux - http://www.kernel.org
 - NetBSD - http://www.netbsd.org/