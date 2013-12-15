/**
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
module kernel.config;

import core.stdc.stdint;
import kernel.trace.trace;
import kernel.arch.architecture;
import kernel.boot.multiboot;
import kernel.mem.phys;

version( X86_64 )
{
	import kernel.arch.x86.bda;
	import kernel.arch.x86.port;
}
else version( X86 )
{
	import kernel.arch.x86.bda;
	import kernel.arch.x86.port;
}



/**
 Linker provided symbols
 */
extern(C)
{
	extern const char _kernelVMA[];
	extern const char _kernelLMA[];
	extern const char _tlsstart[];
	extern const char _tlsend[];
	extern const char _start[];
	extern const char _end[];
}

/**
 Access system properties
 */
class Config
{
	/**
	 Initialize config
	 */
	public static void Initialize( uint32_t multibootMagic, uintptr_t* multibootInfo )
	{
		if( Port.Peek!(uint8_t)( BDA.Port.BOCHS ) == BDA.Port.BOCHS ) {
			_bAvailable = true;
		}

		if( !Multiboot.Initialize( multibootMagic, Phys.ptrToVirtual!(uintptr_t)( multibootInfo ) ) ) {
			Trace.printf( "Wrong multiboot magic: %x !", multibootMagic );
			Cpu.Halt();
		}

		_commandLine = Multiboot.commandLine;
		Cpu.debugBreak();
		/*if( Multiboot.isV2 ) {
			_fBuffer = Multiboot2.frameBuffer.fbAddr;
			_consoleColumns = cast(uint16_t)Multiboot2.frameBuffer.fbWidth;
			_consoleRows = cast(uint16_t)Multiboot2.frameBuffer.fbHeight;
		}*/
	}

	/**
	 Virtual memory offset
	 */
	version(X86_64)
	{
		private static const _offset = 0xFFFFFEFF00000000;
	}
	else version(X86)
	{
		private static const _offset = 0x0;
	}

	@property
	{
		public static uintptr_t vOffset()
		{
			return _offset;
		}
	}

	/**
	 Kernel LMA
	 */
	@property
	{
		public static uintptr_t kernelLMA()
		{
			return (cast(uintptr_t)&_kernelLMA);
		}
	}

	/**
	 Kernel VMA
	 */
	@property
	{
		public static uintptr_t kernelVMA()
		{
			return (cast(uintptr_t)&_kernelVMA);
		}
	}

	/**
	 Kernel end address
	 */
	@property
	{
		public static uintptr_t kernelEnd()
		{
			return (cast(uintptr_t)&_end);
		}
	}

	/**
	 Kernel start address
	 */
	@property
	{
		public static uintptr_t kernelStart()
		{
			return (cast(uintptr_t)&_start);
		}
	}

	/**
	 Defines wether bochs is available
	 */
	private __gshared bool _bAvailable = false;

	@property
	{
		public static bool bochsAvailable()
		{
			return _bAvailable;
		}
	}

	/**
	 Framebuffer address
	 */
	private __gshared uintptr_t _fBuffer = 0xb8000UL;

	@property
	{
		public static uintptr_t frameBuffer()
		{
			return _fBuffer;
		}

		public static uintptr_t frameBuffer( uintptr_t location )
		{
			return _fBuffer = location;
		}
	}

	/**
	 Console columns
	 */
	private __gshared uint16_t _consoleColumns = 80;

	@property
	{
		public static uint16_t consoleColumns()
		{
			return _consoleColumns;
		}
	}

	/**
	 Console rows
	 */
	private __gshared uint16_t _consoleRows = 24;

	@property
	{
		public static uint16_t consoleRows()
		{
			return _consoleRows;
		}
	}

	/**
	 Kernel commandline
	 */
	private __gshared char[] _commandLine;

	@property
	{
		public static char[] commandLine()
		{
			return _commandLine;
		}
	}
}