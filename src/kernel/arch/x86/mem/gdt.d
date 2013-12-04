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
module kernel.arch.x86.mem.gdt;

import kernel.common;

/**
 GDT managment
 - http://www.lowlevel.eu/wiki/GDT
 - http://www.lowlevel.eu/wiki/Teil_5_-_Interrupts#Global_Descriptor_Table
 - http://wiki.osdev.org/GDT
 - http://wiki.osdev.org/GDT_Tutorial
 */
class Gdt
{
	/**
	 GDT Entry
	 - http://www.lowlevel.eu/wiki/GDT#Struktur
	 */
	struct Entry
	{
		align(1):
		ushort limitLow;
		ushort baseLow;
		ubyte  baseMid;
		ubyte  flags;
		ubyte  granularity;
		ubyte  baseHigh;
	};

	/**
	 GDT table, loaded via lidt
	 */
	private __gshared Entry[6] table;

	/**
	 Segment selector
	 */
	public enum Selector : ushort
	{
		NULL	= 0x0000,
		KCODE 	= 0x0008,
		KDATA	= 0x0010,
		UDATA	= 0x0018,
		UCODE	= 0x0020,
		TSS		= 0x0028 /* occupies two GDT descriptors */
	}

	/**
	 Segment flags
	 - http://www.lowlevel.eu/wiki/GDT#Die_Flags
	 - http://www.lowlevel.eu/wiki/GDT#Das_Access-Byte
	 - http://wiki.osdev.org/Segmentation
	 */
	public enum Flags : ubyte
	{
		CS			= 0x18,
		DS			= 0x10,
		TSS			= 0x09,
		WRITABLE	= 0x02,
		USER		= 0x60,
		PRESENT		= 0x80,
		LONGMODE	= 0x2,
		GRANULARITY4K	= 0x8
	}

	/**
	 Initialize GDT
	 - http://www.lowlevel.eu/wiki/GDT#Einrichten_der_GDT
	 */
	public static void Initialize()
	{
		Trace.print( " * GDT: " );

		setEntry( Selector.NULL, 0, 0 );
		setEntry( Selector.KCODE, Flags.PRESENT | Flags.CS, Flags.LONGMODE );
		setEntry( Selector.KDATA, Flags.PRESENT | Flags.DS | Flags.WRITABLE, 0 );
		setEntry( Selector.UCODE, Flags.PRESENT | Flags.CS | Flags.USER, Flags.LONGMODE );
		setEntry( Selector.UDATA, Flags.PRESENT | Flags.DS | Flags.USER | Flags.WRITABLE, 0 );

		struct Base
		{
			align(1):
			ushort limit;
			ulong base;
		}

		Base pointer;
		pointer.limit = (ulong.sizeof * table.length) - 1;
		pointer.base = cast(ulong)table.ptr;

		version(GNU) {
			asm{ "lgdt %0" : : "m" (pointer); }
		} else version(LDC) {
			asm { lgdt pointer; }
		}

		Trace.print( "initialized.\n" );
	}

	/**
	 Set a GDT segment
	 */
	static public void setEntry( ushort sel, ubyte flags, ubyte gran, ulong limit = 0xfffff, ulong base = 0 )
	{
		Entry *entry = &table[sel / Entry.sizeof];
		entry.flags = flags;
		entry.granularity = cast(ubyte)((gran << 4) | ((limit >> 16) & 0x0F));
		entry.limitLow = (limit & 0xFFFF);
		entry.baseLow = (base & 0xFFFF);
		entry.baseMid = ((base >> 16) & 0xFF);
		entry.baseHigh = ((base >> 24) & 0xFF);
	}
}