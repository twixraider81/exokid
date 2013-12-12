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

import os, subprocess, sys, re
from waflib import Build, Context, Scripting, Utils, Task, TaskGen
from waflib.Build import BuildContext
from waflib.ConfigSet import ConfigSet 
from waflib.Tools import ccroot

APPNAME = 'exokid'
VERSION = '0.0.1'

TOP = os.path.abspath( os.curdir )
CCDIR = TOP + '/cc/' + re.findall( '^[a-zA-Z]+', os.uname()[0] )[0] + '/bin/'
RTDIR = 'gdc/libphobos/libdruntime/'
SRCDIR = 'src/'
SUPPORTDIR = TOP + '/support/'
IMAGE = TOP + '/build/kernel.img'
KERNEL = TOP + '/build/kernel.bin'
CONF = 'build/c4che/_cache.py'

# initialization
#def init(ctx):
#	ctx.load('build_logs')

# load options
def options(opt):
	#opt.load( 'gcc' )
	opt.load( 'nasm' )
	#opt.load( 'compiler_c' )
	opt.load( 'ar' )
	opt.load( 'gas' )
	opt.load( 'eclipse' )
	opt.load( 'objcopy' )
	opt.load( 'd' )

	opt.add_option( '--arch', action = 'store', default = 'x64', help = 'the architecture to build comma seperated (x64 or x64,x32)' )
	opt.add_option( '--mode', action = 'store', default = 'debug', help = 'the mode to compile in (debug or release)' )
	opt.add_option( '--compiler', action = 'store', default = 'gdc', help = 'the compiler to use (gdc, ldc2 or dmd2)' )


# configure target
def configure(conf):
	# configure assembler & select cross compiler
	if conf.options.arch == 'x64' or conf.options.arch == 'x86_64-pc-elf':
		tuple = 'x86_64-pc-elf'
		conf.load( 'nasm' )
		conf.env.append_value( 'ASFLAGS', [ '-felf64', '-Ox', '-s', '-Wfloat-denorm', '-Wgnu-elf-extensions', '-Werror' ] )

		if conf.options.mode == 'debug':
			conf.env.append_value( 'DFLAGS', ['-g','-Fdwarf'] ) # -m amd64 -g dwarf2 for yasm?

		conf.find_program( 'qemu-system-x86_64', var = 'QEMU', mandatory = False )
	elif conf.options.arch == 'x32' or conf.options.arch == 'i686-pc-elf':
		tuple = 'i686-pc-elf'
		conf.load( 'nasm' )
		conf.env.append_value( 'ASFLAGS', [ '-felf32', '-Ox', '-s', '-Wfloat-denorm', '-Wgnu-elf-extensions', '-Werror' ] )

		if conf.options.mode == 'debug':
			conf.env.append_value( 'DFLAGS', ['-g','-Fdwarf'] )

		conf.find_program( 'qemu-system-i386', var = 'QEMU', mandatory = False )
	else:
		conf.fatal( '--arch invalid architecture.' )


	# store arch & mode for later reuse
	conf.env.ARCH = conf.options.arch;
	conf.env.MODE = conf.options.mode;


	conf.find_program( 'awk', var = 'AWK', mandatory = True )
	conf.find_program( 'grep', var = 'GREP', mandatory = True )
	conf.find_program( 'tar', var = 'TAR', mandatory = False )
	conf.find_program( 'less', var = 'LESS', mandatory = False )
	conf.find_program( 'gdb', var = 'GDB', mandatory = False )
	conf.find_program( 'kdbg', var = 'KDBG', mandatory = False )
	conf.find_program( tuple + '-gcc', var='CC', path_list=CCDIR, mandatory = True )
	conf.find_program( tuple + '-ar', var='AR', path_list=CCDIR, mandatory = True )
	conf.find_program( tuple + '-ld', var = 'LD', path_list=CCDIR, mandatory = True )
	conf.find_program( tuple + '-as', var = 'AS', path_list=CCDIR, mandatory = True )
	conf.find_program( tuple + '-objdump', var='OBJDUMP', path_list=CCDIR, mandatory = True )
	conf.find_program( tuple + '-objcopy', var = 'OBJCOPY', path_list=CCDIR, mandatory = True )
	conf.find_program( tuple + '-nm', var = 'NM', path_list=CCDIR, mandatory = True )
	#conf.load( 'gcc' )
	#conf.load( 'compiler_c' )
	conf.load( 'objcopy' )


	# detect compiler & tools
	if conf.options.compiler == 'gdc':
		conf.find_program( tuple + '-gdc', path_list=CCDIR, var='D', mandatory = True )
		conf.load( 'gdc' )
	elif conf.options.compiler == 'ldc2' or conf.options.compiler == 'ldc':
		conf.find_program( 'ldc2', path_list=CCDIR, var='D', mandatory = True )
		conf.fatal( 'ldc2 and dmd unsupported for now.' )
		conf.load( 'ldc2' )
	elif conf.options.compiler == 'dmd2' or conf.options.compiler == 'dmd':
		conf.fatal( 'ldc2 and dmd unsupported for now.' )
		conf.find_program( 'dmd2', path_list=CCDIR, var='D', mandatory = True )
		conf.load( 'dmd' )
	else:
		conf.fatal( '--compiler invalid compiler.' )


	# gdc specifics
	if conf.options.compiler == 'gdc':
		# common flags for compiler and linker
		conf.env.append_value( 'DFLAGS', ['-fversion=BareMetal', '-march=native', '-mno-red-zone', '-nostdinc', '-nostdlib', '-mno-mmx', '-mno-3dnow', '-fno-bounds-check'] )
		conf.env.append_value( 'LDFLAGS', ['-z defs', '-nostdlib', '-z max-page-size=0x1000'] )

		# release mode
		if conf.options.mode == 'release':
			conf.env.append_value( 'DFLAGS', ['-O2'] )
		# debug mode
		elif conf.options.mode == 'debug':
			conf.env.append_value( 'DFLAGS', ['-O0', '-g', '-fdebug'] )

		# x64 specifics
		if conf.options.arch == 'x64':
			conf.env.append_value( 'DFLAGS', ['-m64', '-mcmodel=kernel'] )
			conf.env.append_value( 'LDFLAGS', ['-T ../' + SRCDIR + 'kernel/arch/x86/x64/link.ld'] )
		# x32 specifics
		elif conf.options.arch == 'x32':
			conf.env.append_value( 'DFLAGS', ['-m32'] )
			conf.env.append_value( 'LDFLAGS', ['-T ../' + SRCDIR + 'kernel/arch/x86/x32/link.ld'] )
	# ldc specifics
	elif conf.options.compiler == 'ldc2':
		# common flags for compiler and linker
		conf.env.append_value( 'DFLAGS', ['-nodefaultlib', '-disable-simplify-drtcalls', '-disable-simplify-libcalls', '-w', '-x86-early-ifcvt', '-float-abi=hard', '-fatal-assembler-warnings', '-enable-asserts'] )
		conf.env.append_value( 'LDFLAGS', ['-z defs', '-nostdlib', '-z max-page-size=0x1000'] )

		# release mode
		if conf.options.mode == 'release':
			conf.env.append_value( 'DFLAGS', ['-O2'] )
		# debug mode
		elif conf.options.mode == 'debug':
			conf.env.append_value( 'DFLAGS', ['-O0', '-d-debug', '-g'] )

		# x64 specifics
		if conf.options.arch == 'x64':
			conf.env.append_value( 'DFLAGS', ['-m64', '-code-model=kernel', '-disable-red-zone'] )
			conf.env.append_value( 'LDFLAGS', ['-T ../' + SRCDIR + 'kernel/arch/x86/x64/link.ld'] )
		# x32 specifics
		elif conf.options.arch == 'x32':
			conf.env.append_value( 'DFLAGS', ['-m32'] )
			conf.env.append_value( 'LDFLAGS', ['-T ../' + SRCDIR + 'kernel/arch/x86/x32/link.ld'] )


# custom link, this is awefull...
class kernel(ccroot.link_task):
	shell = True
	run_str = '${LD} ${LDFLAGS} -o ${TGT} ${SRC} libdruntime.a'
	ext_out = ['.bin']
	color = 'CYAN'
	inst_to = None


# create bochs symbol table
@TaskGen.feature('sym')
@TaskGen.after_method('kernel')
def sym(self):
	kernel_output = self.link_task.outputs[0]
	self.syms_task = self.create_task( 'sym', src = kernel_output, tgt = self.path.find_or_declare(kernel_output.change_ext('.sym').name) )

class sym(Task.Task):
	shell = True
	run_str = '${NM} -n ${SRC} | ${GREP} -v \'\( [aUw] \)\|\(__crc_\)\|\( \$[adt]\)\' | ${AWK} \'{print $1, $3}\' > ${TGT}'
	ext_out = ['.sym']
	color = 'CYAN'
	inst_to = None


# create bootable image
@TaskGen.feature('image')
@TaskGen.after_method('kernel')
def image(self):
	kernel_output = self.link_task.outputs[0]
	self.syms_task = self.create_task( 'image', src = kernel_output, tgt = self.path.find_or_declare(kernel_output.change_ext('.img').name) )

class image(Task.Task):
	shell = True
	if re.findall( '^[a-zA-Z]+', os.uname()[0] )[0] == "CYGWIN":
		run_str = 'xzcat -f ' + SUPPORTDIR + 'fat32.img.xz > ${TGT}; ' + CCDIR + 'mcopy ' + SUPPORTDIR + 'grub.cfg z:/BOOT/GRUB/GRUB.CFG;  ' + CCDIR + 'mcopy ${SRC} z:/BOOT/KERNEL.BIN'
	else:
		run_str = 'mkdir tmp; xzcat -f ' + SUPPORTDIR + 'ext2.img.xz > ${TGT}; mount -o loop,offset=1048576 ${TGT} tmp; cp ${SRC} tmp/boot; cp ' + SUPPORTDIR + 'grub.cfg tmp/boot/grub/; umount tmp; rmdir tmp'

	ext_out = ['.img']
	color = 'CYAN'
	inst_to = None


# build target
def build(bld):
	# druntime
	bld.stlib( source = bld.path.ant_glob( RTDIR + '**/*.d'), target='druntime', includes=[RTDIR] )

	# kernel binary
	sources = bld.path.ant_glob( SRCDIR + '**/*.d')

	if bld.env.ARCH == 'x64':
		sources += bld.path.ant_glob( SRCDIR + 'kernel/arch/x86/*.S' )
		sources += bld.path.ant_glob( SRCDIR + 'kernel/arch/x86/x64/*.S' )
	elif bld.env.ARCH == 'x32':
		sources += bld.path.ant_glob( SRCDIR + 'kernel/arch/x86/*.S' )
		sources += bld.path.ant_glob( SRCDIR + 'kernel/arch/x86/x32/*.S' )

	bld( features="d asm kernel sym image", target='kernel.bin', use='druntime', source=sources, includes=[RTDIR,SRCDIR] )


# todo target
def todo(ctx):
	"Show todos"
	env = ConfigSet()
	env.load( ctx.path.make_node( CONF ).abspath() )
	subprocess.call( env.GREP + ' -Hnr "//FIXME" '  + SRCDIR, shell=True )


# backup target
def backup(ctx):
	"Create backup at ~/backup/"
	env = ConfigSet()
	env.load( ctx.path.make_node( CONF ).abspath() )
	subprocess.call( env.TAR + ' --exclude cc --exclude logs --exclude build --exclude gdc/.git --exclude gdc/gcc -vcj '  + TOP + ' -f ~/backup/exokid-$(date +%Y-%m-%d-%H-%M).tar.bz2', shell=True )


# bochs target
def bochs(ctx):
	"Start bochs with settings from support/bochsrc and load kernel.img"
	subprocess.call( CCDIR + 'bochs -qf '  + SUPPORTDIR + 'bochsrc', shell=True )


# qemu target
def qemu(ctx):
	"Start qemu and load kernel.img"
	env = ConfigSet()
	env.load( ctx.path.make_node( CONF ).abspath() )

	if env.ARCH == 'x64':
		subprocess.call( env.QEMU + ' --no-reboot -no-shutdown -s -S -smp 2 -m 512 -monitor stdio -serial stdio -hda ' + IMAGE, shell=True )
	elif env.ARCH == 'x32':
		subprocess.call( env.QEMU + ' --no-reboot -no-shutdown -s -S -m 512 -monitor stdio -serial stdio -kernel ' + KERNEL, shell=True )


# gdb target
def gdb(ctx):
	"Start GDB and load kernel.bin"
	env = ConfigSet()
	env.load( ctx.path.make_node( CONF ).abspath() )
	subprocess.call( env.GDB + ' --tui --eval-command="target remote :1234" ' + KERNEL, shell=True )


# gdb target
def kdbg(ctx):
	"Start KDBG and load kernel.bin"
	env = ConfigSet()
	env.load( ctx.path.make_node( CONF ).abspath() )
	subprocess.call( env.KDBG + ' -r :1234  ' + KERNEL, shell=True )


# disasm target
def disasm(ctx):
	"Dump dissasmbled binary"
	env = ConfigSet()
	env.load( ctx.path.make_node( CONF ).abspath() )
	subprocess.call( env.OBJDUMP + ' -S ' + KERNEL + ' | ' + env.LESS, shell=True )
