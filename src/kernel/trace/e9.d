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
module kernel.trace.e9;

import kernel.trace.device;
import kernel.arch.x86.port;
import kernel.arch.x86.bda;

/**
 Trace device for the bochs console
 */
class E9 : Device
{
	public static bool Initialize()
	{
		return ( Port.Peek!(ubyte)( BDA.Port.BOCHS ) == BDA.Port.BOCHS );
	}

	static public void putChar( char c )
	{
		Port.Poke!(ubyte)( BDA.Port.BOCHS, c );
	}
}