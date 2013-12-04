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
module kernel.trace.device;

/**
 Abstract tracing device. Only needs to be able to output single chars.
 */
abstract class Device
{
	/**
	 Initialize the device
	 */
	public static bool Initialize();

	/**
	 Output a character
	 */
	static public void putChar( char c );
}