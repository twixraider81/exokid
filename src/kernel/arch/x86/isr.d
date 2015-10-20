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
module kernel.arch.x86.isr;

import core.stdc.stdint;
import kernel.trace.trace;
import kernel.arch.architecture;

/**
 Mixins to generate assembler hooks
 */
template generateIsrExceptions( uint32_t n, int32_t i = 0 ) 
{
	static if( i > n ) 
		const char[] generateIsrExceptions = ``;
	else
		const char[] generateIsrExceptions = `void isrException` ~ i.stringof ~ `(); ` ~ generateIsrExceptions!( n, i + 1 );
}
	
template generateIsrIrqs( uint32_t n, int32_t i = 0 ) 
{
	static if( i > n ) 
		const char[] generateIsrIrqs = ``;
	else
		const char[] generateIsrIrqs = `void isrIrq` ~ i.stringof ~ `(); ` ~ generateIsrIrqs!( n, i + 1 );
}

template generateExceptionGates( uint32_t n, int32_t i = 0 ) 
{
	static if( i > n ) 
		const char[] generateExceptionGates = ``;
	else
		const char[] generateExceptionGates = `setGate( table[` ~ i.stringof ~ `], &isrException` ~ i.stringof ~ `, Flags.PRESENT | Flags.INTERRUPT ); ` ~ generateExceptionGates!( n, i + 1 );
}
	
template generateIrqGates( uint32_t n, int32_t i = 0 ) 
{
	static if( i > n ) 
		const char[] generateIrqGates = ``;
	else
		const char[] generateIrqGates = `setGate( table[32+` ~ i.stringof ~ `], &isrIrq` ~ i.stringof ~ `, Flags.PRESENT | Flags.INTERRUPT ); ` ~ generateIrqGates!( n, i + 1 );
}

/**
 Interrupt handler structure, should probably be a delegate
 */
alias void function(CpuState*) IdtHandler;

extern(C)
{
	/**
	Common ISR handler, called from assembler routines
	*/
	void isrHandler( CpuState* state )
	{
		if( state.interrupt <= 31 ) {
			version( X86_64 )
			{
				Trace.printf( "\n\nException %d: %s\nCode: %d, flags: %d\n\ncs: %x\tds: %x\tss: %x\nrsp:%x\nrip: %x\nrsi: %x\nrdi: %x\nrbp: %x\n\nrax:%x\nrbx:%x\nrcx:%x\nrdx:%x\n", state.interrupt, Idt.faultNames[state.interrupt], state.error, state.eflags, state.cs, state.ds, state.ss, state.rsp, state.rip, state.rsi, state.rdi, state.rbp, state.rax, state.rbx, state.rdx );
			}
			else version(X86)
			{
				Trace.printf( "\n\nException %d: %s\nCode: %d, flags: %d\n\ncs: %x\tds: %x\tss: %x\nesp:%x\neip: %x\nesi: %x\nedi: %x\nebp: %x\n\neax:%x\nebx:%x\necx:%x\nedx:%x\n", state.interrupt, Idt.faultNames[state.interrupt], state.error, state.eflags, state.cs, state.ds, state.ss, state.esp, state.eip, state.esi, state.edi, state.ebp, state.eax, state.ebx, state.edx );
			}
	
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
	