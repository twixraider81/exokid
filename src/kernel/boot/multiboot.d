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
module kernel.boot.multiboot;

import core.stdc.stdint;
import kernel.trace.trace;
import kernel.boot.multiboot1;
import kernel.boot.multiboot2;

/**
 Manage and use Multiboot structures.‎
 */
class Multiboot
{
	/**
	 Multiboot V1 Magic
	 */
	private static const _magicV1 = 0x2badb002;

	/**
	 Multiboot V2 Magic
	 */
	private static const _magicV2 = 0x36d76289;

	/**
	 Pointer to multiboot structure, provided by the bootloader
	 */
	private __gshared uint32_t _mbMagic;

	/**
	 Initialize Multiboot
	 */
	public static bool Initialize( uint32_t multibootMagic, uintptr_t* infoAddr )
	{
		_mbMagic = multibootMagic;

		if( isV2 ) {
			Trace.printf( "Multiboot2 info found: %x\n", infoAddr );
			return Multiboot2.Initialize( infoAddr );
		}

		if( isV1 ) {
			Trace.printf( "Multiboot1 info found: %x\n", infoAddr );
			return Multiboot1.Initialize( infoAddr );
		}

		return false;
	}

	@property
	{
		public static bool isV1()
		{
			return ( _mbMagic == _magicV1 );
		}
	}

	@property
	{
		public static bool isV2()
		{
			return ( _mbMagic == _magicV2 );
		}
	}

	@property
	{
		public static char[] commandLine()
		{
			if( isV2 ) {
				return Multiboot2.commandLine;
			}

			if( isV1 ) {
				return Multiboot1.commandLine;
			}

			return null;
		}
	}

}