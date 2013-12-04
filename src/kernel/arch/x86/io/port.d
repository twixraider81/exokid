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
module kernel.arch.x86.io.port;

import kernel.common;

/**
 x86 IO Port
 - http://wiki.osdev.org/I/O_Ports
 - http://wiki.osdev.org/Inline_Assembly/Examples#I.2FO_access
 */
class Port : Common
{
	/**
	 Wait / synchronize
	 */
	public static void Wait()
	{
		version(GNU) {
			asm{ "outb %%al, $0x80" : : "a"(0); }
		} else version(LDC) {
			asm { out 0x80, AL;	}
		}
	}

	/**
	 Read
	 */
	public static T Peek(T)( ushort port, bool iowait = false )
	{
		T retval;

		version(GNU) {
			static if( is(T == ubyte) || is(T == byte) ) {
				asm{ "in %%dx,%%al;" : "=a" retval : "d" port; }
			} else static if( is(T == ushort) || is(T == short) ) {
				asm{ "in %%dx,%%ax;" : "=a" retval : "d" port; }
			} else static if( is(T == uint) || is(T == int) ) {
				asm{ "in %%dx,%%eax;" : "=a" retval : "d" port; }
			} else {
				assert(0);
			}

			if( iowait ) {
				asm{ "out %%al, $0x80;" : : ; }
			}
		}  else version(LDC) {
			asm { mov EDX, port; }

			static if( is(T == ubyte) || is(T == byte) ) {
				asm{ in AL, DX; }
			} else static if( is(T == ushort) || is(T == short) ) {
				asm{ in AX, DX; }
			} else static if( is(T == uint) || is(T == int) ) {
				asm{ in EAX, DX; }
			} else {
				assert(0);
			}

			asm { mov retval, EDX; }

			if( iowait ) {
				asm{ out 0x80, AL; }
			}
		}

		return retval;
	}

	/**
	 Write
	 */
	public static void Poke(T)( ushort port, intptr_t data, bool iowait = false )
	{
		version(GNU) {
			static if( is(T == ubyte) || is(T == byte) ) {
				asm{ "outb %%al, %1" : : "a"(data), "Nd"(port); }
			} else static if( is(T == ushort) || is(T == short) ) {
				asm{ "outw %%ax, %1" : : "a"(data), "Nd"(port); }
			} else static if( is(T == uint) || is(T == int) ) {
				asm{ "outl %%eax, %1" : : "a"(data), "Nd"(port); }
			} else {
				assert(0);
			}

			if( iowait ) {
				asm{ "out %%al, $0x80;" : : ; }
			}
		} else version(LDC) {
			asm { mov EAX, data; mov EDX, port;	}

			static if( is(T == ubyte) || is(T == byte) ) {
				asm{ out DX, AL; }
			} else static if( is(T == ushort) || is(T == short) ) {
				asm{ out DX, AX; }
			} else static if( is(T == uint) || is(T == int) ) {
				asm{ out DX, EAX; }
			} else {
				assert(0);
			}
			
			if( iowait ) {
				asm{ out 0x80, AL; }
			}
		}
	}
}