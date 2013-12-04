/**
 Allgemeine Konsolenfunktionen
 */
module kernel.console.trace;

import kernel.common;

/**
 Klasse zum Ausgeben von Meldungen und benötigte Hilfsfunktionen.
 Z.b. Nummerformatierung via printf(), oder getopt()
 */
class Trace
{
	/**
	 Ausgabemedium, Kombination von Device Flags
	 */
	private __gshared int outputDevice;

	/**
	 Verfügbare Ausgabedevices
	 */
	public enum Device : uint
	{
		VGA		= 0x1,
		UART	= 0x2,
		E9		= 0x4
	};

	/**
	 Initialisiert das Tracing
	 */
	public static void Initialize( int mode = Device.E9 | Device.VGA | Device.UART )
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
	 Gibt ein einzelnes Zeichen aus
	 //FIXME: sollte eine verzögerung enthalten um Zeichen nicht zu schnell auszugeben
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
	 Gibt ein einen String/mehrere Zeichen aus.
	 */
	static public void print( const string s )
	{
		foreach( char c; s ) {
			printChar( c );
		}
	}

	/**
	 Formatiert einen string und gibt ihn aus.
	 Formatparameter:
	 	- %s
	 	- %d/%u
	 	- %x
	 	- %b
	 */
	static public void printf( const string s, ... )
	{
		char token;

		for( int i = 0; i < s.length; i++ ) {
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

					print( cast(string)utoa( buf, token, va_arg!( ulong )( _argptr ) ) );
				} else if( token == 's' ) {
					print( va_arg!( string )( _argptr ) );
				}
			}
		}
	}

	/**
	 Wandelt eine Ganzzahl in einen String
	 */
	static public char[] utoa(char[] buf, char base, ulong d)
	{
		ulong p = buf.length - 1;
		ulong startIdx = 0;
		ulong ud = d;
		bool negative = false;
		int divisor = 10;

		if( base == 'x' ) divisor = 16;
		else if( base == 'b' ) divisor = 2;

		do {
			int remainder = cast(int)(ud % divisor);
			buf[p--] = cast(char)((remainder < 10) ? remainder + '0' : remainder + 'a' - 10);
		}
		while( ud /= divisor );

		if( negative ) buf[p--] = '-';

		return buf[p + 1 .. $];
	}
}