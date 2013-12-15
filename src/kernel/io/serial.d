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
module kernel.io.serial;

import kernel.io.common;
import core.stdc.stdint;

version( X86_64 )
{
	import kernel.arch.x86.bda;
	import kernel.arch.x86.port;
}
else version( X86 )
{
	import kernel.arch.x86.bda;
	import kernel.arch.x86.port;
}

/**
 UART / serial port
 - http://www.lowlevel.eu/wiki/Serielle_Schnittstelle
 - http://wiki.osdev.org/UART
 //FIXME: look into hw to abstract for other architectures
 */
class Serial : Common
{
	static const IER	= 0x1;
	static const FCR	= 0x2;
	static const LCR	= 0x3;
	static const MCR	= 0x4;
	static const LSR	= 0x5;
	static const DLAB	= 0x80;
	static const RXTX	= 0x0;
	static const TXRD	= 0x20;
	static const BIT8	= 0x03;
	static const FREQ	= 115200;

	/**
	 Initialize
	 */
	public static bool Initialize( ubyte addr, int baud = 9600 )
	{
		ushort port = BDA.Peek!(ushort)( addr );
		if( !port ) return false;

		/* Interrupts deaktivieren */
		Port.Poke!(ubyte)( cast(ushort)(port + IER), 0x0 );

		// DLAB-Bit setzen
		Port.Poke!(ubyte)( cast(ushort)(port + LCR), DLAB );

		ushort divisor = cast(ushort)(FREQ / baud);
		Port.Poke!(ubyte)( cast(ushort)(port + RXTX), divisor);
		Port.Poke!(ubyte)( cast(ushort)(port + IER), divisor >> 8);

		// 8 Bitformat setzen
		Port.Poke!(ubyte)( cast(ushort)(port + LCR), BIT8 );

		// Initialisierung abschliessen
		Port.Poke!(ubyte)( cast(ushort)(port + FCR), 0xC7 );
		Port.Poke!(ubyte)( cast(ushort)(port + MCR), 0x0B );

		return true;
	}

	/**
	 Check if we can read from the bus
	 */
	private static ubyte isPeekReady( ushort port )
	{
		return ( Port.Peek!(ubyte)( cast(ushort)(port + LSR) ) & 1 );
	}


	/**
	 Read from the bus
	 //FIXME: it blocks
	 */
	public static T Peek(T)( ubyte addr )
	{
		ushort port = BDA.Peek!(ushort)( addr );
		if( !port ) return;

		while( !isPeekReady( port ) ) {
		}

		return Port.Peek!(T)( port );
	}

	/**
	 Check if we can write to the bus
	 */
	private static ubyte isPokeReady( ushort port )
	{
		return ( Port.Peek!(ubyte)( cast(ushort)(port + LSR) ) & TXRD );
	}

	/**
	 Write to the bus
	 //FIXME: it blocks
	 */
	public static void Poke(T)( ubyte addr, intptr_t data )
	{
		ushort port = BDA.Peek!(ushort)( addr );
		if( !port ) return;

		while( !isPokeReady( port ) ) {
		}

		Port.Poke!(ubyte)( cast(ushort)(port), data );
	}
}