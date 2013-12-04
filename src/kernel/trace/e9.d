/**
 E9 Port Ausgabe
 */
module kernel.console.e9;

import kernel.common;

/**
 Ausgabegerät für E9 Port / Bochs Konsole
 */
class E9 : Device
{
	public static bool Initialize()
	{
		return ( Port.Peek!(ubyte)( 0xe9 ) == 0xe9 );
	}

	static public void putChar( char c )
	{
		Port.Poke!(ubyte)( 0xe9, c );
	}
}