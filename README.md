exokid - an EXOkernel In D
==========================
    (In its infancy)

Quickstart
----------
- ./bootstrap.sh
- ./waf configure
- ./waf build:x64

Look at ./waf --help for further commands, like
todo, backup, bochs, qemu, ...


Building
--------
To start the build process first execute bootstrap.sh.
The script will check for necessary tools and compile a cross compiler toolchain.
Even if the bootstrap script can build dmd and ldc compilers, only building the kernel via gdc is supported at
this moment. 

- ./bootstrap.sh -av "x86_64-pc-elf i686-pc-elf"
- -a : cross compiler architecture to build, defaults to x86_64-pc-elf. i.e. (x86_64-pc-elf | "x86_64-pc-elf i686-pc-elf aarch64-none-elf")
- -c : force cleanup (delete downloaded folders)
- -k : keep downloaded archives
- -b : choose which backends to build, defaults to gdc. i.e. (gdc | "gdc ldc dmd")
- -v : verbose, print what the script is doing

This will take a serious amount of time (and disk space), please be patient.

The compiler toolchain will reside under ./cc/$SYSTEMTYPE/ (i.e. cc/Linux, cc/CYGWIN, etc).
Do not delete this folder!
For Cygwin build ldc and dmd are not available. They will only build with a few manual fixes.
(Clang exception linking & WIN32 defines, configuring libconfig build system etc.)

For ldc your system will need libconfig++-dev.
For Bochs you will need libx11-dev & libgtk2.0-dev.


Windows note:
You will need Cygwin and add the path to your Cygwin\bin, Qemu and Python installtion path to
your systems environment path variable.
Please note that ifyou will need a Cygwin Python, not the Windows native one.


After the bootstrap script completed, go ahead configure & build the sources.
- ./waf configure --arch=x64,x32 --compiler=gdc
- ./waf build:x64


Development environment
-----------------------
You will need Eclipse and the CDT and DDT plugins.
Open the project settings dialog, go to "C/C++ Build" and change the PYTHON variable in the category environment.
You can configure, build and run from within Eclipse. Just select the desired configuration first.
First start "Clean Project" which will configure and clean the build.
Next start the build process "Build Project".
In order to be able to run and debug from within Eclipse you will have to go to Run/Debug Settings in the Project
Properties.
Edit a configuration and modify the PYTHON variable according to your system again.
You should create debug configuration for a c/c++ remote application, with the manual gdb remote launcher and
select port 1234 in connection settings. Start a Qemu build and point the configuration to the appropriate kernel.bin.


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
 - XOmB Exokernel - http://www.xomb.org/
 - Arc Kernel - https://github.com/grahamedgecombe/arc/
 - GNU - https://www.gnu.org/
 - Linux - https://www.kernel.org/
 - NetBSD - https://www.netbsd.org/
 - waf - https://code.google.com/p/waf/
 - Eclipse Foundation - https://www.eclipse.org/
 - EFF - https://www.eff.org
 - Stefan Weil - http://qemu.weilnetz.de/
