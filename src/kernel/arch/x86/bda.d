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
module kernel.arch.x86.bda;

import kernel.io.common;
import kernel.mem.phys;

/**
 Access Bios Data Area
 - http://www.lowlevel.eu/wiki/BIOS_Data_Area
 */
class BDA : Common
{
	/**
	 Common data ports
	 */
	public enum Port : ubyte
	{
		COM1	= 0x00,
		COM2	= 0x02,
		COM3	= 0x04,
		COM4	= 0x06,
		LPT1	= 0x08,
		LPT2	= 0x0A,
		LPT3	= 0x0C,
		EWORD	= 0x10,
		BOCHS	= 0xE9
	}

	public static T Peek(T)( ushort offset )
	{
		return *(cast(T*)( Phys.physToVirtual( 0x400 + offset ) ) );
	}
}