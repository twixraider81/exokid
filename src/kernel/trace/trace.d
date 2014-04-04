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
module kernel.trace.trace;

import kernel.trace.e9;
import kernel.trace.uart;
import kernel.trace.vga;
import core.stdc.stdint;
import core.vararg;

/**
 Tracing class. Redirects messages to the appropriate devices.
 Includes message formatting via printf()
 */
class Trace
{
	/**
	 Selected output device
	 */
	private __gshared int32_t outputDevice;

	/**
	Available output devices
	 */
	public enum Device : uint
	{
		VGA		= 0x1,
		UART	= 0x2,
		E9		= 0x4
	};

	/**
	 Initialize tracing devices
	 */
	public static void Initialize( int32_t mode = Device.E9 | Device.VGA | Device.UART )
	{
		outputDevice = 0;

		if( mode & Device.E9 ) {
			if( E9.Initialize() ) {
				outputDevice |= Device.E9;
			}
		}

		if( mode & Device.UART ) {
			if( UART.Initialize() ) {
				outputDevice |= Device.UART;
			}
		}

		if( mode & Device.VGA ) {
			if( VGA.Initialize() ) {
				outputDevice |= Device.VGA;
			}
		}
	}

	/**
	 Output a single char.
	 //FIXME: should contain some sort of syncing or delay
	 */
	static public void printChar( char c )
	{
		if( outputDevice & Device.E9 ) {
			E9.putChar( c );
		}

		if( outputDevice & Device.UART ) {
			UART.putChar( c );
		}

		if( outputDevice & Device.VGA ) {
			VGA.putChar( c );
		}
	}

	/**
	 Output a string
	 */
	static public void print( const string s )
	{
		foreach( char c; s ) {
			printChar( c );
		}
	}

	/**
	 Format and output a string
	 Possible parameters:
	 	- %s
	 	- %d/%u
	 	- %x
	 	- %b
	 */
	static public void printf( const string s, ... )
	{
		char token;

		for( int32_t i = 0; i < s.length; i++ ) {
			token = s[i];

			if( token != '%' ) {
				printChar( token );
			} else {
				i++;

				if( i > s.length ) {
					return;
				}

				token = s[i];

				if( token == 'd' || token == 'b' || token == 'x' || token == 'u' ) {
					char buf[1024];

					if( token == 'x' ) {
						printChar( '0' );
						printChar( 'x' );
					}

					print( cast(string)utoa( buf, token, va_arg!( uintptr_t )( _argptr ) ) );
				} else if( token == 's' ) {
					print( va_arg!( string )( _argptr ) );
				}
			}
		}
	}

	/**
	 Convert number to string using a base
	 */
	static public char[] utoa(char[] buf, char base, uintptr_t d)
	{
		uintptr_t p = buf.length - 1;
		uintptr_t startIdx = 0;
		uintptr_t ud = d;
		bool negative = false;
		int32_t divisor = 10;

		if( base == 'x' ) divisor = 16;
		else if( base == 'b' ) divisor = 2;

		do {
			int32_t remainder = cast(int)(ud % divisor);
			buf[p--] = cast(char)((remainder < 10) ? remainder + '0' : remainder + 'a' - 10);
		}
		while( ud /= divisor );

		if( negative ) buf[p--] = '-';

		return buf[p + 1 .. $];
	}
}