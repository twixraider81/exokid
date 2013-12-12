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
module kernel.arch.x86.config;

import kernel.common;

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
	public static void Initialize( ulong multibootMagic, ulong* multibootInfo )
	{
		if( Port.Peek!(ubyte)( BDA.Port.BOCHS ) == BDA.Port.BOCHS ) {
			bAvailable = true;
		}
		Cpu.debugBreak();
		version(X86_64)
		{
			if( !Multiboot2.Initialize( multibootMagic, PhysMem.ptrToVirtual( multibootInfo ) ) ) {
	
				Trace.Initialize();
				Trace.printf( "Wrong multiboot magic: %x !", multibootMagic );
	
				Cpu.Halt();
				return; // eher symbolischer natur...
			}
	
			if( Multiboot2.frameBuffer ) {
				fBuffer = Multiboot2.frameBuffer.fbAddr;
				_consoleColumns = cast(ushort)Multiboot2.frameBuffer.fbWidth;
				_consoleRows = cast(ushort)Multiboot2.frameBuffer.fbHeight;
			}
		}
	}

	/**
	 Virtual memory offset
	 */
	version(X86_64)
	{
		private static const offset = 0xFFFFFEFF00000000;
	}
	else version(X86)
	{
		private static const offset = 0xFFFF8000000;
	}

	@property
	{
		public static ulong vOffset()
		{
			return offset;
		}
	}

	/**
	 Kernel LMA
	 */
	@property
	{
		public static ulong kernelLMA()
		{
			return (cast(ulong)&_kernelLMA);
		}
	}

	/**
	 Kernel VMA
	 */
	@property
	{
		public static ulong kernelVMA()
		{
			return (cast(ulong)&_kernelVMA);
		}
	}

	/**
	 Kernel end address
	 */
	@property
	{
		public static ulong kernelEnd()
		{
			return (cast(ulong)&_end);
		}
	}

	/**
	 Kernel start address
	 */
	@property
	{
		public static ulong kernelStart()
		{
			return (cast(ulong)&_start);
		}
	}

	/**
	 Defines wether bochs is available
	 */
	private __gshared bool bAvailable = false;

	@property
	{
		public static bool bochsAvailable()
		{
			return bAvailable;
		}
	}

	/**
	 Framebuffer address
	 */
	private __gshared ulong fBuffer = 0xb8000UL;

	@property
	{
		public static ulong frameBuffer()
		{
			return fBuffer;
		}

		public static ulong frameBuffer( ulong location )
		{
			return fBuffer = location;
		}
	}

	/**
	 Console columns
	 */
	private __gshared ushort _consoleColumns = 80;

	@property
	{
		public static ushort consoleColumns()
		{
			return _consoleColumns;
		}
	}

	/**
	 Console rows
	 */
	private __gshared ushort _consoleRows = 24;

	@property
	{
		public static ushort consoleRows()
		{
			return _consoleRows;
		}
	}
}