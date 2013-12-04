/**
 Multibootv2 Strukturen
 - http://nongnu.askapache.com/grub/phcoder/multiboot.pdf‎
 - http://www.lowlevel.eu/wiki/Multiboot#Multiboot-Structure
 */
module kernel.boot.multiboot2;

import kernel.common;

/**
 Klasse zum Auslesen der Multibootv2 Infos.
 */
class Multiboot2
{
	/**
	 Erwartete Bootloader Magic
	 */
	private static const bootldrMagic = 0x36d76289;

	/**
	 Pointer auf die Multiboot Info, wird vom Bootloader übergeben
	 */
	private __gshared Info* info;

	/**
	 Interner String Puffer
	 */
	private __gshared char[1024] buffer = "";

	/**
	 Ausschrift der Multibootinfo Tags
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
	 Ausschrift der MemoryMap Regionen
	 */
	public static const string[6] memoryTypeNames = [
		"Available", "Reserved", "ACPI reclaimable", "ACPI NVS", "Bad", "Unknown"
	];

	/**
	 Typen die ein Multibootinfo Tag annehmen kann
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
	 Typen die der Framebuffer annehmen kann
	 */
	public enum framebufferType : ubyte
	{
		INDEXED	= 0,
		RGB		= 1,
		EGA   	= 2
	};

	/**
	 Typen die ein MemoryMap Eintrag annehmen kann
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
	 Basisstruktur der Multiboot v2 Info
	 */
	private struct Info
	{
		align(1):

		/**
		 Grösse inkl aller Tags
		 */
		public uint totalSize;

		/**
		 Reserviert!?
		 */
		public uint reserved;
	}

	/**
	 Initialisiert die Multiboot
	 */
	public static bool Initialize( ulong multibootMagic, void* infoAddr )
	{
		if( multibootMagic != bootldrMagic ) {
			return false;
		}

		info = cast(Info*)infoAddr;		
		return true;
	}

	/**
	 Liest ein Multi Infotag aus
	 */
	private static T getTag( T )( uint tType )
	{
		ulong tagAddr = cast(ulong)info + Info.totalSize.sizeof + Info.reserved.sizeof;
		ulong tagLimit = tagAddr + info.totalSize;
		while( tagAddr < tagLimit ) {
			Tag* tag = cast(Tag*)tagAddr;

			if( tag.tagType == tagType.TERMINATOR ) return null;

			if( tag.tagType == tType ) return (cast(T) tag);

			// align
    		ulong size =  ( ( ( tag.tagSize ) + 7 ) & 0xFFFFFFFFFFFFFFF8 );
    		tagAddr += size;
    	}

		return null;
	}

	/**
	 Multiboot Commandozeile
	 */
	@property
	{
		public static char[] commandLine()
		{
			TagString* line = getTag!( TagString* )( tagType.CMDLINE );
			ulong length = line.tagSize - line.tagType.sizeof - line.tagSize.sizeof;
	
			for( ulong i = 0; ( i < length || i < buffer.length); i++ ) {
				buffer[i] = line.str[i];
			}
	
			return buffer[ 0 .. length ];
		}
	}

	/**
	 Multiboot Bootloadername
	 */
	@property
	{
		public static char[] bootLoader()
		{
			TagString* line = getTag!( TagString* )( tagType.BOOTLDR );
			ulong length = line.tagSize - line.tagType.sizeof - line.tagSize.sizeof;

			for( ulong i = 0; ( i < length || i < buffer.length); i++ ) {
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
 Basisstruktur eines Multiboot Tags
 */
struct Tag
{
	/**
	 Typ des Tags, siehe tagTypes
	 */
	public uint tagType;

	/**
	 Grösse des Tags
	 */
	public uint tagSize;
};

/**
 Multiboot String Tag
 */
struct TagString
{
	/**
	 Typ des Tags, siehe tagTypes
	 */
	public uint tagType;

	/**
	 Grösse des Tags
	 */
	public uint tagSize;

	/**
	Pointer auf den String
	*/
	public char str[0];
};

/**
 Multiboot Framebuffer Tag
 */
struct TagFramebuffer
{
	/**
	 Typ des Tags, siehe tagTypes
	 */
	public uint tagType;

	/**
	 Grösse des Tags
	 */
	public uint tagSize;

	/**
	 Physische Adresse des Framebuffers
	 */
	public ulong fbAddr;

	/**
	 Pitch?
	 */
	public uint fbPitch;

	/**
	 Breite, meist 80
	 */
	public uint fbWidth;

	/**
	 Höhe, meist 25
	 */
	public uint fbHeight;

	/**
	 Bits per Pixel, meist 16
	 */
	public ubyte fbBpp;

	/**
	Framebuffer Typ
	 */
	public ubyte fbType;

	public ushort reserved;
};

/**
 Multiboot Boot device Tag
 */
struct TagBootDevice
{
	/**
	 Typ des Tags, siehe tagTypes
	 */
	public uint tagType;

	/**
	 Grösse des Tags
	 */
	public uint tagSize;
	
	public uint device;
	public uint slice;
	public uint part;
};

/**
 Multiboot Boot device Tag
 */
struct TagAPM
{
	/**
	 Typ des Tags, siehe tagTypes
	 */
	public uint tagType;

	/**
	 Grösse des Tags
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
 Multiboot Framebuffer Tag
 */
struct TagMemoryInfo
{
	/**
	 Typ des Tags, siehe tagTypes
	 */
	public uint tagType;

	/**
	 Grösse des Tags
	 */
	public uint tagSize;

	/**
	 Untere Speichergrenze
	 */
	public uint memoryLower;

	/**
	 Obere Speichergrenze
	 */
	public uint memoryUpper;
}

/**
 Multiboot Boot device Tag
 */
struct TagMemoryMap
{
	align(1):
	/**
	 Typ des Tags, siehe tagTypes
	 */
	public uint tagType;

	/**
	 Grösse des Tags
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