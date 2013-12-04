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
module kernel.arch.x86.intr.idt;

import kernel.common;

/**
 Interrupt handler structure, should probably be a delegate
 */
alias void function(CpuState*) IdtHandler;

/**
 Mixins to generate assembler hooks
 */
template generateIsrExceptions( uint n, int i = 0 ) 
{
	static if( i > n ) 
		const char[] generateIsrExceptions = ``;
	else
		const char[] generateIsrExceptions = `void isrException` ~ i.stringof ~ `(); ` ~ generateIsrExceptions!( n, i + 1 );
}

template generateIsrIrqs( uint n, int i = 0 ) 
{
	static if( i > n ) 
		const char[] generateIsrIrqs = ``;
	else
		const char[] generateIsrIrqs = `void isrIrq` ~ i.stringof ~ `(); ` ~ generateIsrIrqs!( n, i + 1 );
}

template generateExceptionGates( uint n, int i = 0 ) 
{
	static if( i > n ) 
		const char[] generateExceptionGates = ``;
	else
		const char[] generateExceptionGates = `setGate( table[` ~ i.stringof ~ `], &isrException` ~ i.stringof ~ `, Flags.PRESENT | Flags.INTERRUPT ); ` ~ generateExceptionGates!( n, i + 1 );
}

template generateIrqGates( uint n, int i = 0 ) 
{
	static if( i > n ) 
		const char[] generateIrqGates = ``;
	else
		const char[] generateIrqGates = `setGate( table[32+` ~ i.stringof ~ `], &isrIrq` ~ i.stringof ~ `, Flags.PRESENT | Flags.INTERRUPT ); ` ~ generateIrqGates!( n, i + 1 );
}


extern(C) {
	/**
	 Common ISR handler, called from assembler routines
	 */
	void isrHandler( CpuState* state )
	{
		if( state.interrupt <= 31 ) { // x64
			Trace.printf( "\n\nException %d: %s\nCode: %d, flags: %d\n\ncs: %x\tds: %x\tss: %x\nrsp:%x\nrip: %x\nrsi: %x\nrdi: %x\nrbp: %x\n\nrax:%x\nrbx:%x\nrcx:%x\nrdx:%x\nr8: %x\nr9: %x\nr10: %x\nr11: %x\nr12: %x\nr12: %x\nr13: %x\nr14: %x\nr15: %x\n", state.interrupt, Idt.faultNames[state.interrupt], state.error, state.eflags, state.cs, state.ds, state.ss, state.rsp, state.rip, state.rsi, state.rdi, state.rbp, state.rax, state.rbx, state.rdx, state.r8, state.r9, state.r10, state.r11, state.r12, state.r13, state.r14, state.r15 );
			Cpu.debugBreak();
			Cpu.Halt();
		}

		if( Idt.handlers[state.interrupt] is null ) {
			return;
		}

		Idt.handlers[state.interrupt]( state );
	};

	void isrIpiPanic();
	void isrIpiTlb();
	void isrLapicTimer();
	void isrLapicError();
	void isrLapicSpurious();

	/**
	 External isr routines
	 */
	alias void function() isrCallback;

	mixin( generateIsrExceptions!(31) );
	mixin( generateIsrIrqs!(23) );
}

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
		ushort addrLow;
		ushort csSel;
		ubyte ist;
		ubyte flags;
		ushort addrMid;
		uint addrHigh;
		uint reserved2;
	}

	/**
	 IDT table, loaded via lidt
	 */
	private __gshared Entry[256] table;

	/**
	 IDT handler mappings
	 */
	private __gshared IdtHandler[256] handlers;

	/**
	 Exception names
	 */
	public const static string[32] faultNames = [ "Divide by Zero Error", "Debug", "Non Maskable Interrupt", "Breakpoint", "Overflow", "Bound Range", "Invalid Opcode", "Device Not Available", "Double Fault", "Coprocessor Segment Overrun", "Invalid TSS", "Segment Not Present", "Stack-Segment Fault", "General Protection Fault", "Page Fault", "Reserved", "x87 Floating-Point Exception", "Alignment Check", "Machine Check", "SIMD Floating-Point Exception", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Reserved", "Security Exception", "Reserved" ];

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
		Trace.print( " * IDT: " );

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
			ushort limit;
			ulong base;
		}

		Base pointer;
		pointer.limit = (ulong.sizeof * table.length) - 1;
		pointer.base = cast(ulong)table.ptr;

		version(GNU) {
			asm{ "lidt %0" : : "m" (pointer); }
		} else version(LDC) {
			asm { lidt pointer; }
		}

		Trace.print( "initialized.\n" );
	}

	/**
	 Set a single gate
	 */
	private static void setGate( ref Entry gate, isrCallback handler, ubyte flags )
	{
		ulong addr = cast(ulong)handler;
		gate.csSel = 0x08;
		gate.addrLow = addr & 0xFFFF;
		gate.addrMid = (addr >> 16) & 0xFFFF;
		gate.addrHigh = (addr >> 32) & 0xFFFFFFFF;
		gate.flags = flags;
	}

	/**
	 Activate interrupts
	 */
	public static void Enable()
	{
		version(GNU) {
			asm{ "sti;"; }
		} else version(LDC) {
			asm{ sti; }
		}

		Trace.print( " * Interrupts: enabled.\n" );
	}

	/**
	 Deactivate interrupts
	 */
	public static void Disable()
	{
		version(GNU) {
			asm{ "cli;"; }
		} else version(LDC) {
			asm{ cli; }
		}

		Trace.print( " * Interrupts: disabled.\n" );
	}
}