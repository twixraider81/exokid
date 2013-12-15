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
module kernel.boot.multiboot1;

import core.stdc.stdint;
import kernel.trace.trace;

/**
 Manage and use Multiboot structures.‎
 - http://www.lowlevel.eu/wiki/Multiboot#Multiboot-Structure
 */
class Multiboot1
{
	/**
	 Possible multiboot infos
	 */
	private enum hasInfo : uint
	{
		MEMORY	= 0x00000001,
		BOOTDEV	= 0x00000002,
		CMDLINE	= 0x00000004,
		MODULES	= 0x00000008,
		AOUT	= 0x00000010,
		ELF		= 0x00000020,
		MMAP	= 0x00000040,
		DRIVES	= 0x00000080,
		CONFIG	= 0x00000100,
		LOADER	= 0x00000200,
		APM		= 0x00000400,
		VBE		= 0x00000800
	}

	/**
	 Multiboot V1 info structure
	 */
	private struct Info
	{
		align(1):

		public uint32_t flags;

		/* if hasInfo.MEMORY */
    	public uint32_t memoryLower;
    	public uint32_t memoryUpper;

    	/* if hasInfo.BOOTDEV */
    	public uint8_t	bootDevicePart3;
    	public uint8_t	bootDevicePart2;
    	public uint8_t	bootDevicePart1;
    	public uint8_t	bootDeviceDrive;

    	/* if hasInfo.CMDLINE */
    	public uint32_t	cmdLine;

    	/* if hasInfo.MODULES */
    	public uint32_t	moduleCount;
    	public uint32_t	moduleAddr;

    	/* if hasInfo.ELF || if hasInfo.AOUT */
    	public uint32_t	elfShdrNum;
    	public uint32_t	elfShdrSize;
    	public uint32_t	elfShdrAddr;
    	public uint32_t	elfShdrShndx;

    	/* if hasInfo.MMAP */
    	public uint32_t	mmapLength;
    	public uint32_t	mmapAddr;

    	/* if hasInfo.DRIVES */
    	public uint32_t	drivesLength;
    	public uint32_t	drivesAddr;

    	/* if hasInfo.CONFIG */
    	public uint32_t	configTable;

    	/* if hasInfo.LOADER */
    	public uint32_t	loaderName;

    	/* if hasInfo.APM */
    	public uint32_t	apmTable;

    	/* if hasInfo.VBE */
    	public uint32_t	vbeControl;
    	public uint32_t	vbeMode;
    	public uint32_t	vbeInterfaceSeg;
    	public uint32_t	vbeInterfaceOff;
    	public uint32_t	vbeInterfaceLen;
	}

	/**
	 Pointer to multiboot structure, provided by the bootloader
	 */
	private __gshared Info* _info;

	/**
	 Initialize multiboot1 reader
	 */
	public static bool Initialize( void* addr )
	{
		_info = cast(Info*)addr;		
		return true;
	}

	/**
	 Multiboot commandline
	 */
	@property
	{
		public static char[] commandLine()
		{
			if( _info.flags & hasInfo.CMDLINE ) {
				Trace.printf( "\ncmd: %s\n", _info.cmdLine );
				//return (cast(char*)_info.cmdLine);
			}

			return null;
		}
	}
}