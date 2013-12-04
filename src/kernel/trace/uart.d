/**
 Ausgabe via Serialport
 */
module kernel.console.uart;

import kernel.common;

/**
 Serielle Konsole
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