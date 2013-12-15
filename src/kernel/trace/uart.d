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
module kernel.trace.uart;

import kernel.trace.device;
import kernel.arch.x86.bda;
import kernel.io.serial;
import core.stdc.stdint;

/**
 Tracing device for the serial port, only com1 atm
 */
class UART : Device
{
	public static bool Initialize()
	{
		return Serial.Initialize( BDA.Port.COM1 );
	}

	static public void putChar( char c )
	{
		if( c == '\n' ) {
			putChar( '\r' );
		}

		Serial.Poke!(ubyte)( BDA.Port.COM1, c );
	}
}