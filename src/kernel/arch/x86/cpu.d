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
module kernel.arch.x86.cpu;

import core.stdc.stdint;
import kernel.trace.trace;
import kernel.config;
import kernel.arch.x86.pic;
import kernel.arch.x86.gdt;

public
{
	version( X86_64 )
	{
		import kernel.arch.x86.x64.state;
		import kernel.arch.x86.x64.idt;
	}
	else version( X86 )
	{
		import kernel.arch.x86.x32.state;
		import kernel.arch.x86.x32.idt;
	}
}

/**
 CPU Interface
 */
class Cpu
{
	/**
	 IDT interface
	 */
	public static Idt idt;

	/**
	 GDT interface
	 */
	public static Gdt gdt;

	/**
	 PIC interface
	 */
	public static Pic pic;

	/**
	 Initialize boot processor
	 */
	public static void Initialize()
	{
		version( GNU )
		{
			asm{ "cli;"; }
		}
		else
		{
			asm{ cli; }
		}

		if( Config.bochsAvailable ) {
			Trace.print( " * Bochs: found, breakpoints enabled.\n" );
		} else {
			Trace.print( " * Bochs: not found.\n" );
		}

		gdt.Initialize();
		idt.Initialize();
		pic.Initialize();
	}

	/**
	 Halt CPU
	 */
	public static void Halt()
	{
		version( GNU )
		{
			asm{ "cli; l: hlt; jmp l;"; }
		}
		else
		{
			asm{ cli; l: hlt; jmp l; }
		}
	}

	/**
	 Do nothing
	 */
	public static void Noop()
	{
		version( GNU )
		{
			asm{ "nop; nop; nop;"; }
		}
		else
		{
			asm{ nop; nop; nop; }
		}
	}

	/**
	 Activate interrupts
	 */
	public static void enableInterrupts()
	{
		version( GNU )
		{
			asm{ "sti;"; }
		}
		else
		{
			asm{ sti; }
		}
	
		Trace.print( " * Interrupts: enabled.\n" );
	}
	
	/**
	 Deactivate interrupts
	 */
	public static void disableInterrupts()
	{
		version( GNU )
		{
			asm{ "cli;"; }
		}
		else
		{
			asm{ cli; }
		}
	
		Trace.print( " * Interrupts: disabled.\n" );
	}

	/**
	 Insert a bochs breakpoint
	 */
	static public void debugBreak()
	{
		if( !Config.bochsAvailable ) {
			return;
		}
		
		version( GNU )
		{
			asm{ "xchg %%bx, %%bx"; }
		}
		else
		{
			asm{ xchg BX, BX; }
		}
	}
}