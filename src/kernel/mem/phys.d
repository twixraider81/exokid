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
module kernel.mem.phys;

import core.stdc.stdint;
import kernel.trace.trace;
import kernel.config;

extern(C) void memset(void* addr, uint8_t val, uint32_t numBytes);

/**
 Physische Speicherverwaltung
 - http://www.lowlevel.eu/wiki/Teil_7_-_Physische_Speicherverwaltung
 - http://www.lowlevel.eu/wiki/Physische_Speicherverwaltung
 - http://wiki.osdev.org/Paging
 - http://wiki.osdev.org/Page_Frame_Allocation
 - http://www.brokenthorn.com/Resources/OSDev17.html
 */
class Phys
{
	public static const pageSize = 4096;
	public static const busSize = uintptr_t.sizeof * 8;

	private __gshared uintptr_t availableMemory = 0;
	private __gshared uintptr_t blocksUsed = 0;
	private __gshared uintptr_t blocksMax = 0;
	private __gshared uintptr_t* memoryMap = null;
	
	public static void Initialize()
	{
		Trace.printf( " * PMM\n" );
	}

	/**
	 Liefert die virtuelle Adresse zu einer physischen Adresse
	 */
	public static uintptr_t physToVirtual( uintptr_t addr )
	{
		return cast(uintptr_t)( Config.vOffset + addr);
	}

	/**
	 Liefert die virtuelle Adresse zu einem Pointer
	 */
	public static T* ptrToVirtual(T)( T* ptr )
	{
		uintptr_t addr = cast(uintptr_t)ptr;
		addr += Config.vOffset;
		return (cast(T*)addr);
	}

	/**
	 VGA Framebuffer
	 */
	@property
	{
		public static uint8_t* frameBuffer()
		{
			return cast(uint8_t*)( Config.vOffset + Config.frameBuffer);
		}
	}
}