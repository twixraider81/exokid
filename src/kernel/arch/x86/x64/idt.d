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
module kernel.arch.x86.x64.idt;

import core.stdc.stdint;
import kernel.trace.trace;
import kernel.arch.architecture;
import kernel.arch.x86.isr;

version( X86_64 )
{
	/**
	 Manage Interrupts
	 - http://www.lowlevel.eu/wiki/Interrupt_Descriptor_Table
	 - http://wiki.osdev.org/Interrupt_Descriptor_Table
	 */
	class Idt
	{
		/**
		 Structure of a single idt entry
		 - http://www.lowlevel.eu/wiki/Interrupt_Descriptor_Table#Deskriptor
		 - http://wiki.osdev.org/IDT#Structure
		 */
		struct Entry
		{
			align (1):
			uint16_t addrLow;
			uint16_t csSel;
			uint8_t ist;
			uint8_t flags;
			uint16_t addrMid;
			uint32_t addrHigh;
			uint32_t reserved2;
		}
	
		/**
		 IDT table, loaded via lidt
		 */
		private __gshared Entry[256] table;
	
		/**
		 IDT handler mappings
		 */
		public __gshared IdtHandler[256] handlers;
	
		/**
		 Exception names
		 */
		public const static string[32] faultNames = [ "Divide by Zero Error", "Debug", "Non Maskable Interrupt", "Breakpoint", "Overflow", "Bound Range", "Invalid Opcode", "Device Not Available", "Double Fault", "Coprocessor Segment Overrun", "Invalid TSS", "Segment Not Present", "Stack-Segment Fault", "General Protection Fault", "Page Fault", "Reserved", "x87 Floating-Point32_t Exception", "Alignment Check", "Machine Check", "SIMD Floating-Point32_t Exception", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Security Exception", "Reserved" ];
	
		/**
		 Interrupt flags
		 */
		public enum Flags
		{
			PRESENT		= 0x80,
			USER		= 0x60,
			INTERRUPT	= 0x0E,
			TRAP		= 0x0F
		}
	
		/**
		 Initialize IDT
		 */
		public static void Initialize()
		{
			Trace.print( " * IDT 64bit: " );
	
			mixin( generateExceptionGates!(31) );
			mixin( generateIrqGates!(23) );
	
			// ipi
			setGate( table[0xFB], &isrIpiPanic, Flags.PRESENT | Flags.INTERRUPT );
			setGate( table[0xFC], &isrIpiTlb, Flags.PRESENT | Flags.INTERRUPT );
	
			// lapic lvt
			setGate( table[0xFD], &isrLapicTimer, Flags.PRESENT | Flags.INTERRUPT );
			setGate( table[0xFE], &isrLapicError, Flags.PRESENT | Flags.INTERRUPT );
			setGate( table[0xFF], &isrLapicSpurious, Flags.PRESENT | Flags.INTERRUPT );
	
			struct Base
			{
				align (1):
				uint16_t limit;
				uint64_t base;
			}
	
			Base pointer;
			pointer.limit = (uint64_t.sizeof * table.length) - 1;
			pointer.base = cast(uint64_t)table.ptr;
	
			version( GNU )
			{
				asm{ "lidt %0" : : "m" (pointer); }
			}
			else
			{
				asm { lidt pointer; }
			}
	
			Trace.print( "initialized.\n" );
		}
	
		/**
		 Set a single gate
		 */
		private static void setGate( ref Entry gate, isrCallback handler, uint8_t flags )
		{
			uintptr_t addr = cast(uintptr_t)handler;
			gate.csSel = 0x08;
			gate.addrLow = addr & 0xFFFF;
			gate.addrMid = (addr >> 16) & 0xFFFF;
			gate.addrHigh = (addr >> 32) & 0xFFFFFFFF;
			gate.flags = flags;
		}
	}
}