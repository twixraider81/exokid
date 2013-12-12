/**
 Physische Speicherverwaltung
 - http://www.lowlevel.eu/wiki/Teil_7_-_Physische_Speicherverwaltung
 - http://www.lowlevel.eu/wiki/Physische_Speicherverwaltung
 - http://wiki.osdev.org/Paging
 - http://wiki.osdev.org/Page_Frame_Allocation
 - http://www.brokenthorn.com/Resources/OSDev17.html
 */
module kernel.arch.x86.mem.physmem;

import kernel.common;

extern(C) void memset(void* addr, ubyte val, uint numBytes);

class PhysMem
{
	public static const pageSize = 4096;
	public static const busSize = uintptr_t.sizeof * 8;

	private __gshared uintptr_t availableMemory = 0;
	private __gshared uintptr_t blocksUsed = 0;
	private __gshared uintptr_t blocksMax = 0;
	private __gshared uintptr_t* memoryMap = null;
	
	public static void Initialize()
	{
		Trace.printf( "\n * PMM\n" );
	}

	/**
	 Liefert die virtuelle Adresse zu einer physischen Adresse
	 */
	public static ulong physToVirtual( uintptr_t addr )
	{
		return cast(uintptr_t)( Config.vOffset + addr);
	}

	/**
	 Liefert die virtuelle Adresse zu einem Pointer
	 */
	public static void* ptrToVirtual( void* ptr )
	{
		uintptr_t addr = cast(uintptr_t)ptr;
		addr += Config.vOffset;
		return (cast(void*)addr);
	}

	/**
	 VGA Framebuffer
	 */
	@property
	{
		public static ubyte* frameBuffer()
		{
			return cast(ubyte*)( Config.vOffset + Config.frameBuffer);
		}
	}
}