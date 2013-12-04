/**
 Konsolen Ausgabegerät
 */
module kernel.console.device;

/**
 Abstrakte Klasse um Ausgaben auf einer Konsole zu realisieren.
 Wir brauchen z.Z. nur Ausgabe einzelner Chars.
 */
abstract class Device
{
	/**
	 Initialisiert das Ausgabegerät
	 */
	public static bool Initialize();

	/**
	 Gibt ein Zeichen aus
	 */
	static public void putChar( char c );
}