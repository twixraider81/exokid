/**
 VGA Framebuffer Konsolenfunktionen
 - http://www.lowlevel.eu/wiki/Textausgabe
 */
module kernel.console.vga;

import kernel.common;

/**
 VGA Framebuffer Konsole
 */
class VGA : Device
{
	/**
	 Standardfarben
	 */
	public enum Color : ubyte
	{
		BLACK		= 0x00,
		BLUE		= 0x01,
		GREEN		= 0x02,
		CYAN		= 0x03,
		RED			= 0x04,
		MAGENTA		= 0x05,
		BROWN		= 0x06,
		LIGHTGRAY	= 0x07,
		GRAY		= 0x08,
		LIGHTBLUE	= 0x09,
		LIGHTGREEN	= 0x0A,
		LIGHTCYAN	= 0x0B,
		LIGHTRED	= 0x0C,
		LIGHTMAGENTA	= 0x0D,
		YELLOW		= 0x0E,
		WHITE		= 0x0F
	}

	public static bool Initialize()
	{
		foregroundColor = Color.WHITE;
		backgroundColor = Color.BLACK;

		Reset();

		return true;
	}

	static public void putChar( char c )
	{
		if( c == '\f' || c == '\v' || c == '\a' ) {
			return;
		}

		if( c == '\t' ) { // tab.
			X = X + 4;
		} else if( c != '\n' && c != '\r' ) {
			*(PhysMem.frameBuffer + ( X + Y * Config.consoleColumns ) * 2) = c & 0xFF;
			*(PhysMem.frameBuffer + ( X + Y * Config.consoleColumns ) * 2 + 1) = _colorAttribute;

			X = X + 1;
		}

		if( c == '\n' || c == '\r' || X >= Config.consoleColumns ) {
			X = 0;
			Y = Y+1;

			if( Y >= Config.consoleRows ) {
				scrollLines( 1 );
			}
		}
	}

	/**
	 Aktuelle X Position in der Matrix
	 */
	private __gshared uint _xPos = 0;

	@property
	{
		public static uint X()
		{
			return _xPos;
		}

		public static uint X( uint x )
		{
			if( x >= Config.consoleColumns ) x = Config.consoleColumns - 1;
			return _xPos = x;
		}
	}

	/**
	 Aktuelle Y Position in der Matrix
	 */
	private __gshared uint _yPos = 0;

	@property
	{
		public static uint Y()
		{
			return _yPos;
		}

		public static uint Y( uint y )
		{
			if( y >= Config.consoleRows ) y = Config.consoleRows - 1;
			return _yPos = y;
		}
	}

	/**
	 Farbattribut, ergibt sich aus foregroundColor und backgroundColor
	 */
	private __gshared ubyte _colorAttribute;

	/**
	 Vordergrund / Textfarbe
	 */
	private __gshared ubyte _foregroundColor;

	@property
	{
		public static ubyte foregroundColor()
		{
			return _foregroundColor;
		}

		public static ubyte foregroundColor( ubyte color )
		{
			_colorAttribute = (_colorAttribute & 0xf0) | color;
			return _foregroundColor = color;
		}
	}

	/**
	 Vordergrund / Textfarbe
	 */
	private __gshared ubyte _backgroundColor;

	@property
	{
		public static ubyte backgroundColor()
		{
			return _backgroundColor;
		}

		public static ubyte backgroundColor( ubyte color )
		{
			_colorAttribute = cast(ubyte)((_colorAttribute & 0x0f) | (color << 4));
			return _backgroundColor = color;
		}
	}

	/**
	 Löscht den Screen
	 */
	static public void Reset()
	{
		for( uint i = 0; i < Config.consoleColumns * Config.consoleRows * 2; i++ ) {
			*( PhysMem.frameBuffer + i ) = 0;
		}
	}

	/**
	 Scrollt Zeilen
	 */
	static public void scrollLines( uint numLines )
	{
		if( numLines >= Config.consoleRows ) {
			Reset();
			return;
		}

		uint cury = 0;
		uint offset1 = 0;
		uint offset2 = numLines * Config.consoleColumns;

		for( ; cury <= Config.consoleRows - numLines; cury++ ) {
			for( uint curx = 0; curx < Config.consoleColumns; curx++ ) {
				*(PhysMem.frameBuffer + (curx + offset1) * 2) = *(PhysMem.frameBuffer + (curx + offset1 + offset2) * 2);
				*(PhysMem.frameBuffer + (curx + offset1) * 2 + 1) = *(PhysMem.frameBuffer + (curx + offset1 + offset2) * 2 + 1);
			}

			offset1 += Config.consoleColumns;
		}

		for( ; cury <= Config.consoleRows; cury++ ) {
			for( uint curx = 0; curx < Config.consoleColumns; curx++ ) {
				*(PhysMem.frameBuffer + (curx + offset1) * 2) = 0x00;
				*(PhysMem.frameBuffer + (curx + offset1) * 2 + 1) = 0x00;
			}
		}

		Y = Y - numLines;
	}
}