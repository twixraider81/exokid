#!/usr/bin/env python
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

import os, subprocess, sys, re, platform, pipes
from waflib import Build, Context, Scripting, Utils, Task, TaskGen
from waflib.Build import BuildContext, CleanContext, InstallContext, UninstallContext
from waflib.ConfigSet import ConfigSet 
from waflib.Tools import ccroot

APPNAME = 'exokid'
VERSION = '0.0.1'

TOP = os.path.abspath( os.curdir )
SUPPORTDIR = TOP + '/support/'
CCDIR = TOP + '/cc/' + re.findall( '^[a-zA-Z]+', platform.uname()[0] )[0] + '/bin/'

SRCDIR = 'src/'
RTDIR = SRCDIR + 'druntime/'
KERNELDIR = SRCDIR + 'kernel/'

# initialization, construct pseudo classes
def init( ctx ):
	for x in 'x64,x32,aarch64'.split( ',' ):
		class tmp( CleanContext ):
			cmd = 'clean:' + x
			variant = x

		class tmp( BuildContext ):
			cmd = 'build:' + x
			variant = x

		class tmp( BuildContext ):
			cmd = 'bochs:' + x
			fun = 'bochs'

		class tmp( BuildContext ):
			cmd = 'qemu:' + x
			fun = 'qemu'

		class tmp( BuildContext ):
			cmd = 'gdb:' + x
			fun = 'gdb'

		class tmp( BuildContext ):
			cmd = 'kdbg:' + x
			fun = 'kdbg'

		class tmp( BuildContext ):
			cmd = 'disasm:' + x
			fun = 'disasm'


# load options
def options( opt ):
	opt.load( 'ar' )
	opt.load( 'gas' )
	opt.load( 'd' )

	opt.add_option( '--arch', action = 'store', default = 'x64', help = 'the architecture to build comma seperated (x64 or x64,x32,aarch64)' )
	opt.add_option( '--mode', action = 'store', default = 'debug', help = 'the mode to compile in (debug or release)' )
	opt.add_option( '--compiler', action = 'store', default = 'gdc', help = 'the compiler to use (gdc, ldc2 or dmd2)' )


# configure target
def configure( conf ):
	conf.env.MODE = conf.options.mode;
	conf.env.ARCH = conf.options.arch;

	for arch in conf.options.arch.split( ',' ):
		# store variant
		conf.setenv( arch )

		# common programs
		conf.find_program( 'awk', var = 'AWK', mandatory = True )
		conf.find_program( 'grep', var = 'GREP', mandatory = True )
		conf.find_program( 'less', var = 'LESS', mandatory = False )
		conf.find_program( 'gdb', var = 'GDB', mandatory = False )
		conf.find_program( 'kdbg', var = 'KDBG', mandatory = False )
		conf.find_program( 'tar', var = 'TAR', mandatory = False )

		# cross compiler tuple
		if arch == 'x64':
			tuple = 'x86_64-pc-elf'
		elif arch == 'x32':
			tuple = 'i686-pc-elf'
		elif arch == 'aarch64':
			tuple = 'aarch64-none-elf'
		else:
			conf.fatal( '--arch invalid architecture "' + arch + '"' )

		# arch related programs
		conf.find_program( tuple + '-gcc', var='CC', path_list=CCDIR, mandatory = True )
		conf.find_program( tuple + '-ar', var='AR', path_list=CCDIR, mandatory = True )
		conf.find_program( tuple + '-ld', var = 'LD', path_list=CCDIR, mandatory = True )
		conf.find_program( tuple + '-as', var = 'AS', path_list=CCDIR, mandatory = True )
		conf.find_program( tuple + '-objdump', var='OBJDUMP', path_list=CCDIR, mandatory = True )
		conf.find_program( tuple + '-objcopy', var = 'OBJCOPY', path_list=CCDIR, mandatory = True )
		conf.find_program( tuple + '-nm', var = 'NM', path_list=CCDIR, mandatory = True )
		conf.find_program( 'bochs', var = 'BOCHS', path_list=CCDIR, mandatory = False )
		conf.load( 'gas' )

		if arch == 'x64':
			conf.find_program( 'qemu-system-x86_64', var = 'QEMU', mandatory = False )
		elif arch == 'x32':
			conf.find_program( 'qemu-system-i386', var = 'QEMU', mandatory = False )
		elif arch == 'aarch64':
			conf.find_program( 'qemu-system-arm', var = 'QEMU', mandatory = False )

		if conf.options.compiler == 'gdc':
			conf.find_program( tuple + '-gdc', path_list=CCDIR, var='D', mandatory = True )
			conf.load( 'gdc' )
		elif conf.options.compiler == 'ldc2' or conf.options.compiler == 'ldc':
			conf.fatal( '--compiler, only gdc supported for now.' )
			conf.find_program( 'ldc2', var='D', mandatory = True )
			conf.load( 'ldc2' )
		elif conf.options.compiler == 'dmd2' or conf.options.compiler == 'dmd':
			conf.fatal( '--compiler, only gdc supported for now.' )
			conf.find_program( 'dmd', path_list=CCDIR, var='D', mandatory = True )
			conf.load( 'dmd' )
		else:
			conf.fatal( '--compiler invalid compiler.' )



		#configure toolchain
		conf.env.append_value( 'LDFLAGS', ['-z defs', '-nostdlib', '-z max-page-size=0x1000'] )

		if conf.options.mode == 'release':
			conf.env.append_value( 'DFLAGS', ['-O2'] )
		elif conf.options.mode == 'debug':
			conf.env.append_value( 'DFLAGS', ['-O0', '-g'] )
			conf.env.append_value( 'ASFLAGS', ['--nocompress-debug-sections', '-D', '-g', '--gdwarf-2'] )

		if arch == 'x64':
			conf.env.append_value( 'ASFLAGS', ['-march=generic64', '--64'] )
			conf.env.append_value( 'DFLAGS', ['-m64'] )
			conf.env.append_value( 'LDFLAGS', ['-T ' + TOP + '/src/kernel/arch/x86/x64/link.ld'] )
		elif arch == 'x32':
			conf.env.append_value( 'ASFLAGS', ['-march=generic32', '--32'] )
			conf.env.append_value( 'DFLAGS', ['-m32'] )
			conf.env.append_value( 'LDFLAGS', ['-T ' + TOP + '/src/kernel/arch/x86/x32/link.ld'] )
		elif arch == 'aarch64':
			conf.env.append_value( 'ASFLAGS', ['-march=armv8-a'] )
			conf.env.append_value( 'LDFLAGS', ['-T ' + TOP + '/src/kernel/arch/arm/aarch64/link.ld'] )
		
		# configure compiler specifics
		if conf.options.compiler == 'gdc':
			conf.env.append_value( 'DFLAGS', ['-fversion=BareMetal', '-nostdinc', '-nostdlib', '-fno-bounds-check'] )

			if conf.options.mode == 'debug':
				conf.env.append_value( 'DFLAGS', ['-fdebug'] )

			if arch == 'x64':
				conf.env.append_value( 'DFLAGS', ['-march=native', '-mcmodel=kernel', '-mno-red-zone', '-mno-mmx', '-mno-3dnow' ] )
			elif arch == 'x32':
				conf.env.append_value( 'DFLAGS', ['-march=native', '-mno-mmx', '-mno-3dnow'] )
			elif arch == 'aarch64':
				conf.env.append_value( 'DFLAGS', ['-march=armv8-a', '-mcmodel=large'] )

		elif conf.options.compiler == 'ldc2':
			conf.env.append_value( 'DFLAGS', ['-dw', '-d-version=BareMetal', '-disable-simplify-drtcalls', '-disable-simplify-libcalls', '-ignore', '-march=native', '-nodefaultlib', '-w', '-fatal-assembler-warnings'] )

			if conf.options.mode == 'release':
				conf.env.append_value( 'DFLAGS', ['-release'] )
			elif conf.options.mode == 'debug':
				conf.env.append_value( 'DFLAGS', ['-d-debug', '-enable-asserts','-asm-verbose'] )

			if arch == 'x64':
				conf.env.append_value( 'DFLAGS', ['-code-model=kernel', '-disable-red-zone', '-x86-early-ifcvt'] )
			elif arch == 'x32':
				conf.env.append_value( 'DFLAGS', ['-x86-early-ifcvt'] )

		elif conf.options.compiler == 'dmd':
			conf.env.append_value( 'DFLAGS', ['-dw', '-ignore', '-inline', '-noboundscheck', '-version=BareMetal'] )

			if conf.options.mode == 'release':
				conf.env.append_value( 'DFLAGS', ['-release'] )
			elif conf.options.mode == 'debug':
				conf.env.append_value( 'DFLAGS', ['-debug'] )

	for arch in conf.options.arch.split( ',' ):
		conf.msg( 'configured target build:' + arch + ' / clean:' + arch, True, 'CYAN' )


# custom link, this is awefull...
class kernel( ccroot.link_task ):
	shell = True
	run_str = '${LD} ${LDFLAGS} -o ${TGT} ${SRC} libdruntime.a'
	ext_out = ['.bin']
	color = 'CYAN'
	inst_to = None


# create bochs symbol table
@TaskGen.feature( 'sym' )
@TaskGen.after_method( 'kernel' )
def sym( self ):
	kernel_output = self.link_task.outputs[0]
	self.syms_task = self.create_task( 'sym', src = kernel_output, tgt = self.path.find_or_declare(kernel_output.change_ext( '.sym' ).name ) )

class sym( Task.Task ):
	shell = True
	run_str = '${NM} -n ${SRC} | ${GREP} -v \'\( [aUw] \)\|\(__crc_\)\|\( \$[adt]\)\' | ${AWK} \'{print $1, $3}\' > ${TGT}'
	ext_out = ['.sym']
	color = 'CYAN'
	inst_to = None


# create bootable image
@TaskGen.feature( 'image' )
@TaskGen.after_method( 'kernel' )
def image( self ):
	kernel_output = self.link_task.outputs[0]
	self.syms_task = self.create_task( 'image', src = kernel_output, tgt = self.path.find_or_declare(kernel_output.change_ext( '.img' ).name ) )

class image( Task.Task ):
	shell = True
	if re.findall( '^[a-zA-Z]+', platform.uname()[0] )[0] == "CYGWIN":
		run_str = 'export MTOOLS_SKIP_CHECK=1; xzcat -f ' + SUPPORTDIR + 'fat32.img.xz > ${TGT}; ' + CCDIR + 'mcopy -i ${TGT}@@32256 ' + SUPPORTDIR + 'grub.cfg ::/BOOT/GRUB/GRUB.CFG; ' + CCDIR + 'mcopy -i ${TGT}@@32256 ${SRC} ::/BOOT/KERNEL.BIN'
	else:
		run_str = 'mkdir tmp; xzcat -f ' + SUPPORTDIR + 'ext2.img.xz > ${TGT}; sudo mount -o loop,offset=1048576 ${TGT} tmp; cp ${SRC} tmp/boot; cp ' + SUPPORTDIR + 'grub.cfg tmp/boot/grub/; sudo umount tmp; rmdir tmp'

	ext_out = ['.img']
	color = 'CYAN'
	inst_to = None


# build target
def build( bld ):
	if not bld.variant:
		bld.fatal( 'call ./waf build:x64, clean:x32, build:x32, etc.' )

	# druntime
	rtsources = bld.path.ant_glob( RTDIR + 'object_.d' )
	rtsources += bld.path.ant_glob( RTDIR + 'core/*.d' )
	rtsources += bld.path.ant_glob( RTDIR + 'core/stdc/*.d' )
	rtsources += bld.path.ant_glob( RTDIR + 'gcstub/*.d' )
	rtsources += bld.path.ant_glob( RTDIR + 'rt/*.d' )
	rtsources += bld.path.ant_glob( RTDIR + 'rt/typeinfo/*.d' )
	rtsources += bld.path.ant_glob( RTDIR + 'rt/util/*.d' )
	rtsources += bld.path.ant_glob( RTDIR + 'gcc/*.d' )
	bld.stlib( source = rtsources, target='druntime', includes=[RTDIR] )

	# kernel binary
	sources = bld.path.ant_glob( KERNELDIR + '**/*.d' )

	if bld.variant == 'x64':
		sources += bld.path.ant_glob( KERNELDIR + 'arch/x86/*.S' )
		sources += bld.path.ant_glob( KERNELDIR + 'arch/x86/x64/*.S' )
	elif bld.variant == 'x32':
		sources += bld.path.ant_glob( KERNELDIR + 'arch/x86/*.S' )
		sources += bld.path.ant_glob( KERNELDIR + 'arch/x86/x32/*.S' )

	bld( features="d asm kernel sym image", target='kernel.bin', use='druntime', source=sources, includes=[RTDIR,SRCDIR,KERNELDIR] )



# todo target
def todo( ctx ):
	"Show todos"
	subprocess.call( 'grep -Hnr "//FIXME" '  + SRCDIR, shell=True )

# backup target
def backup( ctx ):
	"Create backup at ~/backup/"
	subprocess.call( 'tar --exclude cc --exclude build -vcj '  + TOP + ' -f ~/backup/exokid-$(date +%Y-%m-%d-%H-%M).tar.bz2', shell=True )

# bochs target
def bochs( BuildContext ):
	"Start bochs with settings from support/bochsrc and load kernel.img"
	arch = BuildContext.cmd.split( ':' )

	if len( arch ) < 2:
		BuildContext.fatal( 'call ./waf bochs:x64, bochs:x32 etc.' )

	arch = arch[1]
	subprocess.call( BuildContext.all_envs[arch].BOCHS + ' -qf '  + SUPPORTDIR + 'bochsrc.' + arch, shell=True )

# qemu target
def qemu( BuildContext ):
	"Start qemu and load kernel.img"
	arch = BuildContext.cmd.split( ':' )

	if len( arch ) < 2:
		BuildContext.fatal( 'call ./waf qemu:x64, qemu:x32 etc.' )

	arch = arch[1]
	cwd = os.getcwd()
	os.chdir( BuildContext.out_dir + '/' + arch )
	cmd = pipes.quote( BuildContext.all_envs[arch].QEMU ) + ' --no-reboot -no-shutdown -S -gdb tcp::1234,ipv4 -smp 2 -m 512 -monitor stdio -hda kernel.img'
	subprocess.call( cmd, shell=True )
	os.chdir( cwd )

# gdb target
def gdb( BuildContext ):
	"Start GDB and load kernel.bin"
	arch = BuildContext.cmd.split( ':' )

	if len( arch ) < 2:
		BuildContext.fatal( 'call ./waf gdb:x64, gdb:x32 etc.' )

	arch = arch[1]
	subprocess.call( BuildContext.all_envs[arch].GDB + ' --eval-command="target remote localhost:1234" ' + BuildContext.out_dir + '/' + arch + '/kernel.bin', shell=True )

# kdbg target
def kdbg( BuildContext ):
	"Start KDBG and load kernel.bin"
	arch = BuildContext.cmd.split( ':' )

	if len( arch ) < 2:
		BuildContext.fatal( 'call ./waf kdbg:x64, kdbg:x32 etc.' )

	arch = arch[1]
	subprocess.call( BuildContext.all_envs[arch].KDBG + ' -r localhost:1234 ' + BuildContext.out_dir + '/' + arch + '/kernel.bin', shell=True )

# disasm target
def disasm( BuildContext ):
	"Disassemble kernel.bin"
	arch = BuildContext.cmd.split( ':' )

	if len( arch ) < 2:
		BuildContext.fatal( 'call ./waf disasm:x64, disasm:x32 etc.' )

	arch = arch[1]
	subprocess.call( BuildContext.all_envs[arch].OBJDUMP + ' -S ' + BuildContext.out_dir + '/' + arch + '/kernel.bin | ' + BuildContext.all_envs[arch].LESS, shell=True )
