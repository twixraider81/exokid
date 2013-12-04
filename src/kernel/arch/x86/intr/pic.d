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
module kernel.arch.x86.intr.pic;

import kernel.common;

/**
 PIC Programing
 - http://www.lowlevel.eu/wiki/Teil_5_-_Interrupts#Programmable_Interrupt_Controller
 - http://www.lowlevel.eu/wiki/PIC_Tutorial
 - http://www.lowlevel.eu/wiki/PIC
 - http://wiki.osdev.org/PIC
 */
class Pic
{
	/**
	 PIC Ports
	 */
	public enum Ports : ubyte
	{
		MASTERCMD	= 0x20,
		MASTERDATA	= 0x21,
		SLAVECMD	= 0xa0,
		SLAVEDATA	= 0xa1
	}

	/**
	 ICW1 Payloads
	 */
	public enum ICW1 : ubyte
	{
		ICW4	= 0x01,
		SINGLE	= 0x02,
		INTERVAL4	= 0x04,
		LEVEL	= 0x08,
		INIT	= 0x10
	}

	/**
	 OCW3 Payloads
	 */
	public enum OCW3 : ubyte
	{
		IRR		= 0x0a,
		ISR		= 0x0b
	}

	/**
	 ICW4 Payloads
	 */
	public enum ICW4 : ubyte
	{
		I8086	= 0x01,
		AUTO	= 0x02,
		BUFSLAVE	= 0x08,
		BUFMASTER	= 0x0C,
		SFNM	= 0x10
	}

	/**
	 Initialisiert the PIC, so IRQs and exceptions don't overlap
	 */
	public static void Initialize( bool useApic = false )
	{
		Trace.print( " * PIC: " );

		if( useApic ) { // apic wird benutzt pic deaktivieren
			Port.Poke!(ubyte)( Ports.SLAVECMD, 0xff );
			Port.Poke!(ubyte)( Ports.MASTERCMD, 0xff );

			Trace.print( "disabled.\n" );

			return;
		}

		ubyte pic1, pic2;

		pic1 = Port.Peek!(ubyte)( Ports.MASTERDATA );
		pic1 = Port.Peek!(ubyte)( Ports.SLAVEDATA );

		Port.Poke!(ubyte)( Ports.MASTERCMD, ICW1.INIT + ICW1.ICW4, true );
		Port.Poke!(ubyte)( Ports.SLAVECMD, ICW1.INIT + ICW1.ICW4, true );

		Port.Poke!(ubyte)( Ports.MASTERDATA, 0x00, true );
		Port.Poke!(ubyte)( Ports.SLAVEDATA, 0x08, true );
  		Port.Poke!(ubyte)( Ports.MASTERDATA, 0x04, true );
  		Port.Poke!(ubyte)( Ports.SLAVEDATA, 0x02, true );
 
   		Port.Poke!(ubyte)( Ports.MASTERDATA, ICW4.I8086, true );
  		Port.Poke!(ubyte)( Ports.SLAVEDATA, ICW4.I8086, true );

  		Port.Poke!(ubyte)( Ports.MASTERDATA, pic1, true );
  		Port.Poke!(ubyte)( Ports.SLAVEDATA, pic2, true );
  
  		Trace.print( "initialized.\n" );
	}

	/**
	 Signalise end of interrupt
	 */
	public static void endOfInterrupt( ushort irq )
	{
		if( irq >= 8) Port.Poke!(ubyte)( Ports.SLAVECMD, 0x20 );
		Port.Poke!(ubyte)( Ports.MASTERCMD, 0x20 );
	}

	/**
	 Read IRR state
	 */
	public static ushort getIrr()
	{
  		Port.Poke!(ubyte)( Ports.MASTERCMD, OCW3.IRR );
  		Port.Poke!(ubyte)( Ports.SLAVECMD, OCW3.IRR );
  		return ( ( Port.Peek!(ubyte)( Ports.SLAVECMD ) << 8) | Port.Peek!(ubyte)( Ports.MASTERCMD ) );
	}

	/**
	 Read den ISR state
	 */
	public static ushort getIsr()
	{
  		Port.Poke!(ubyte)( Ports.MASTERCMD, OCW3.ISR );
  		Port.Poke!(ubyte)( Ports.SLAVECMD, OCW3.ISR );
  		return ( ( Port.Peek!(ubyte)( Ports.SLAVECMD ) << 8) | Port.Peek!(ubyte)( Ports.MASTERCMD ) );
	}
}