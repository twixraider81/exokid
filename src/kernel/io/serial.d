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
	public static bool Initialize( uint8_t addr, int32_t baud = 9600 )
	{
		uint16_t port = BDA.Peek!(uint16_t)( addr );
		if( !port ) return false;

		/* Interrupts deaktivieren */
		Port.Poke!(uint8_t)( cast(uint16_t)(port + IER), 0x0 );

		// DLAB-Bit setzen
		Port.Poke!(uint8_t)( cast(uint16_t)(port + LCR), DLAB );

		uint16_t divisor = cast(uint16_t)(FREQ / baud);
		Port.Poke!(uint8_t)( cast(uint16_t)(port + RXTX), divisor);
		Port.Poke!(uint8_t)( cast(uint16_t)(port + IER), divisor >> 8);

		// 8 Bitformat setzen
		Port.Poke!(uint8_t)( cast(uint16_t)(port + LCR), BIT8 );

		// Initialisierung abschliessen
		Port.Poke!(uint8_t)( cast(uint16_t)(port + FCR), 0xC7 );
		Port.Poke!(uint8_t)( cast(uint16_t)(port + MCR), 0x0B );

		return true;
	}

	/**
	 Check if we can read from the bus
	 */
	private static uint8_t isPeekReady( uint16_t port )
	{
		return ( Port.Peek!(uint8_t)( cast(uint16_t)(port + LSR) ) & 1 );
	}


	/**
	 Read from the bus
	 //FIXME: it blocks
	 */
	public static T Peek(T)( uint8_t addr )
	{
		uint16_t port = BDA.Peek!(uint16_t)( addr );
		if( !port ) return;

		while( !isPeekReady( port ) ) {
		}

		return Port.Peek!(T)( port );
	}

	/**
	 Check if we can write to the bus
	 */
	private static uint8_t isPokeReady( uint16_t port )
	{
		return ( Port.Peek!(uint8_t)( cast(uint16_t)(port + LSR) ) & TXRD );
	}

	/**
	 Write to the bus
	 //FIXME: it blocks
	 */
	public static void Poke(T)( uint8_t addr, intptr_t data )
	{
		uint16_t port = BDA.Peek!(uint16_t)( addr );
		if( !port ) return;

		while( !isPokeReady( port ) ) {
		}

		Port.Poke!(uint8_t)( cast(uint16_t)(port), data );
	}
}