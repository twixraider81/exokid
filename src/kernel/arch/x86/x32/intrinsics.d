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
import core.stdc.stdint;

/**
 libgcc compiler intrinsics
 - http://code.metager.de/source/xref/linux/klibc/usr/klibc/libgcc/
 */
version(X86)
{
	extern(C):

	uint64_t __udivmoddi4( uint64_t num, uint64_t den, uint64_t * rem_p )
	{
		uint64_t quot = 0, qbit = 1;
	
		if( den == 0 ) {
			return 0;
		}
	
		while( cast(int64_t)den >= 0 ) {
			den <<= 1;
			qbit <<= 1;
		}
	
		while( qbit ) {
			if( den <= num ) {
				num -= den;
				quot += qbit;
			}

			den >>= 1;
			qbit >>= 1;
		}
	
		if( rem_p ) *rem_p = num;
	
		return quot;
	}

	uint64_t __umoddi3( uint64_t num, uint64_t den )
	{
		uint64_t v;
		__udivmoddi4( num, den, &v );
		return v;
	}

	uint64_t __udivdi3( uint64_t num, uint64_t den )
	{
		return __udivmoddi4( num, den, null );
	}

	int64_t __divdi3( int64_t num, int64_t den )
	{
		int minus = 0;
		int64_t v;

		if( num < 0 ) {
			num = -num;
			minus = 1;
			}

		if( den < 0 ) {
			den = -den;
			minus ^= 1;
		}

		v = __udivmoddi4( num, den, null );

		if( minus ) v = -v;

		return v;
	}
}