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
module kernel.trace.vga;
import kernel.trace.device;

import kernel.config;
import kernel.mem.phys;
import core.stdc.stdint;

/**
 VGA Framebuffer Device
 - http://www.lowlevel.eu/wiki/Textausgabe
 */
class VGA : Device
{
	/**
	 Common colours
	 */
	public enum Color : uint8_t
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
			*(Phys.frameBuffer + ( X + Y * Config.consoleColumns ) * 2) = c & 0xFF;
			*(Phys.frameBuffer + ( X + Y * Config.consoleColumns ) * 2 + 1) = _colorAttribute;

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
	 Current X Position
	 */
	private __gshared uint32_t _xPos = 0;

	@property
	{
		public static uint32_t X()
		{
			return _xPos;
		}

		public static uint32_t X( uint32_t x )
		{
			if( x >= Config.consoleColumns ) x = Config.consoleColumns - 1;
			return _xPos = x;
		}
	}

	/**
	 Current Y Position
	 */
	private __gshared uint32_t _yPos = 0;

	@property
	{
		public static uint32_t Y()
		{
			return _yPos;
		}

		public static uint32_t Y( uint32_t y )
		{
			if( y >= Config.consoleRows ) y = Config.consoleRows - 1;
			return _yPos = y;
		}
	}

	/**
	 Colour attribute, combines foregroundColor and backgroundColor
	 */
	private __gshared uint8_t _colorAttribute;

	/**
	 Foreground colo(u)r
	 */
	private __gshared uint8_t _foregroundColor;

	@property
	{
		public static uint8_t foregroundColor()
		{
			return _foregroundColor;
		}

		public static uint8_t foregroundColor( uint8_t color )
		{
			_colorAttribute = (_colorAttribute & 0xf0) | color;
			return _foregroundColor = color;
		}
	}

	/**
	 Background colo(u)r
	 */
	private __gshared uint8_t _backgroundColor;

	@property
	{
		public static uint8_t backgroundColor()
		{
			return _backgroundColor;
		}

		public static uint8_t backgroundColor( uint8_t color )
		{
			_colorAttribute = cast(uint8_t)((_colorAttribute & 0x0f) | (color << 4));
			return _backgroundColor = color;
		}
	}

	/**
	 Clear the screen
	 */
	static public void Reset()
	{
		for( uint32_t i = 0; i < Config.consoleColumns * Config.consoleRows * 2; i++ ) {
			*( Phys.frameBuffer + i ) = 0;
		}
	}

	/**
	 Scroll lines
	 */
	static public void scrollLines( uint32_t numLines )
	{
		if( numLines >= Config.consoleRows ) {
			Reset();
			return;
		}

		uint32_t cury = 0;
		uint32_t offset1 = 0;
		uint32_t offset2 = numLines * Config.consoleColumns;

		for( ; cury <= Config.consoleRows - numLines; cury++ ) {
			for( uint32_t curx = 0; curx < Config.consoleColumns; curx++ ) {
				*(Phys.frameBuffer + (curx + offset1) * 2) = *(Phys.frameBuffer + (curx + offset1 + offset2) * 2);
				*(Phys.frameBuffer + (curx + offset1) * 2 + 1) = *(Phys.frameBuffer + (curx + offset1 + offset2) * 2 + 1);
			}

			offset1 += Config.consoleColumns;
		}

		for( ; cury <= Config.consoleRows; cury++ ) {
			for( uint32_t curx = 0; curx < Config.consoleColumns; curx++ ) {
				*(Phys.frameBuffer + (curx + offset1) * 2) = 0x00;
				*(Phys.frameBuffer + (curx + offset1) * 2 + 1) = 0x00;
			}
		}

		Y = Y - numLines;
	}
}