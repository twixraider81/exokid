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
module kernel.boot.multiboot2;

import kernel.common;

/**
 Manage and use Multiboot V2 structures.
 - http://nongnu.askapache.com/grub/phcoder/multiboot.pdf‎
 - http://www.lowlevel.eu/wiki/Multiboot#Multiboot-Structure
 */
class Multiboot2
{
	/**
	 Expected Bootloader Magic
	 */
	private static const bootldrMagic = 0x36d76289;

	/**
	 Pointer to multiboot structure, provided by the bootloader
	 */
	private __gshared Info* info;

	/**
	 Internal string buffer
	 */
	private __gshared char[1024] buffer = "";

	/**
	 Name for multiboot tags
	 */
	public static const string[17] tagNames = [
		"Terminator",
		"Commandline",
		"Bootloader",
		"Module",
		"Memory info",
		"Boot device",
		"Memory map",
		"VBE",
		"Framebuffer",
		"ELF section",
		"APM",
		"EFI32",
		"EFI64",
		"SMBios",
		"ACPI (old)",
		"ACPI (new)",
		"Network"
	];

	/**
	 Name for memory regions
	 */
	public static const string[6] memoryTypeNames = [
		"Available", "Reserved", "ACPI reclaimable", "ACPI NVS", "Bad", "Unknown"
	];

	/**
	 Possible tag type
	 */
	public enum tagType : ubyte
	{
		TERMINATOR	= 0,
		CMDLINE		= 1,
		BOOTLDR   	= 2,
		MODULE		= 3,
		MEMINFO		= 4,
		BOOTDEV		= 5,
		MEMMAP		= 6,
		VBE			= 7,
		FRAMEBUFFER	= 8,
		ELF			= 9,
		APM			= 10,
		EFI32		= 11,
		EFI64		= 12,
		SMBIOS		= 13,
		ACPIOLD		= 14,
		ACPINEW		= 15,
		NETWORK		= 16
	};

	/**
	 Possible framebuffer types
	 */
	public enum framebufferType : ubyte
	{
		INDEXED	= 0,
		RGB		= 1,
		EGA   	= 2
	};

	/**
	 Possible memory region types
	 */
	public enum memoryType : ubyte
	{
		AVAILABLE		= 1,
		RESERVED		= 2,
		ACPI_RECLAIM	= 3,
		ACPI_NVS		= 4,
		BAD				= 5,
		UNKNOWN			= 6
	};

	/**
	 Multiboot V2 info structure
	 */
	private struct Info
	{
		align(1):

		/**
		 Size including tags
		 */
		public uint totalSize;

		/**
		 reserved!?
		 */
		public uint reserved;
	}

	/**
	 Initialize multiboot2 reader
	 */
	public static bool Initialize( uintptr_t multibootMagic, void* infoAddr )
	{
		if( multibootMagic != bootldrMagic ) {
			return false;
		}

		info = cast(Info*)infoAddr;		
		return true;
	}

	/**
	 Reads a tag
	 */
	private static T getTag( T )( uint tType )
	{
		uintptr_t tagAddr = cast(uintptr_t)info + Info.totalSize.sizeof + Info.reserved.sizeof;
		uintptr_t tagLimit = tagAddr + info.totalSize;
		while( tagAddr < tagLimit ) {
			Tag* tag = cast(Tag*)tagAddr;

			if( tag.tagType == tagType.TERMINATOR ) return null;

			if( tag.tagType == tType ) return (cast(T) tag);

			// align
    		uintptr_t size =  ( ( ( tag.tagSize ) + 7 ) & 0xFFFFFFFFFFFFFFF8 );
    		tagAddr += size;
    	}

		return null;
	}

	/**
	 Multiboot commandline
	 */
	@property
	{
		public static char[] commandLine()
		{
			TagString* line = getTag!( TagString* )( tagType.CMDLINE );
			uintptr_t length = line.tagSize - line.tagType.sizeof - line.tagSize.sizeof;
	
			for( uintptr_t i = 0; ( i < length || i < buffer.length); i++ ) {
				buffer[i] = line.str[i];
			}
	
			return buffer[ 0 .. length ];
		}
	}

	/**
	 Multiboot bootloader name
	 */
	@property
	{
		public static char[] bootLoader()
		{
			TagString* line = getTag!( TagString* )( tagType.BOOTLDR );
			uintptr_t length = line.tagSize - line.tagType.sizeof - line.tagSize.sizeof;

			for( uintptr_t i = 0; ( i < length || i < buffer.length); i++ ) {
				buffer[i] = line.str[i];
			}

			return buffer[ 0 .. length ];
		}
	}

	/**
	 Basic Memoryinfo
	 */
	@property
	{
		public static TagMemoryInfo* memoryInfo()
		{
			return getTag!( TagMemoryInfo* )( tagType.MEMINFO );
		}
	}

	/**
	 Framebuffer Info
	 */
	@property
	{
		public static TagFramebuffer* frameBuffer()
		{
			return getTag!( TagFramebuffer* )( tagType.FRAMEBUFFER );
		}
	}

	/**
	 APM Info
	 */
	@property
	{
		public static TagAPM* APM()
		{
			return getTag!( TagAPM* )( tagType.APM );
		}
	}

	/**
	 Bootdevice Info
	 */
	@property
	{
		public static TagBootDevice* bootDevice()
		{
			return getTag!( TagBootDevice* )( tagType.BOOTDEV );
		}
	}

	/**
	 Memorymap
	 */
	@property
	{
		public static TagMemoryMap* memoryMap()
		{
			return getTag!( TagMemoryMap* )( tagType.MEMMAP );
		}
	}
}

/**
 Base structure of a multiboot tag
 */
struct Tag
{
	/**
	 Tag types
	 */
	public uint tagType;

	/**
	 Tag size
	 */
	public uint tagSize;
};

/**
 Structure of a multiboot string tag
 */
struct TagString
{
	/**
	 Tag type
	 */
	public uint tagType;

	/**
	 Tag size
	 */
	public uint tagSize;

	/**
	String pointer
	*/
	public char str[0];
};

/**
 Structure of a multiboot framebuffer Tag
 */
struct TagFramebuffer
{
	/**
	 Tag type
	 */
	public uint tagType;

	/**
	 Tag size
	 */
	public uint tagSize;

	/**
	 Physicak address
	 */
	public ulong fbAddr;

	/**
	 Pitch?
	 */
	public uint fbPitch;

	/**
	 Width, supposedly 80 chars
	 */
	public uint fbWidth;

	/**
	 Height, supposedly 25 chars
	 */
	public uint fbHeight;

	/**
	 Bits per pixel, supposedly 16
	 */
	public ubyte fbBpp;

	/**
	Framebuffer typ
	 */
	public ubyte fbType;

	public ushort reserved;
};

/**
 Structure of a multiboot framebuffer device tag
 */
struct TagBootDevice
{
	/**
	 Tag type
	 */
	public uint tagType;

	/**
	 Tag size
	 */
	public uint tagSize;
	
	public uint device;
	public uint slice;
	public uint part;
};

/**
 Structure of a multiboot APM tag
 */
struct TagAPM
{
	/**
	 Tag type
	 */
	public uint tagType;

	/**
	 Tag size
	 */
	public uint tagSize;

	public ushort apmVersion;
	public ushort cSegment;
	public uint offset;
	public ushort cSegment16;
	public ushort dSegment;
	public ushort apmFlags;
	public ushort cSegmentLength;
	public ushort cSegment16Length;
	public ushort dSegmentLength;
};


/**
 Structure of a multiboot memory info
 */
struct TagMemoryInfo
{
	/**
	 Tag type
	 */
	public uint tagType;

	/**
	 Tag size
	 */
	public uint tagSize;

	public uint memoryLower;
	public uint memoryUpper;
}

/**
 Structure of a multiboot memory map tag
 */
struct TagMemoryMap
{
	align(1):
	/**
	 Tag type
	 */
	public uint tagType;

	/**
	 Tag size
	 */
	public uint tagSize;

	public uint entrySize;
	public uint entryVersion;

	public struct Entry
	{
		align(1):
		ulong baseAddress;
		ulong length;
		uint memoryType;
		uint zero;
	}
	public Entry entries[0];
};