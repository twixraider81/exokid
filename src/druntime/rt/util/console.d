/**
 * The console module contains some simple routines for console output.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.util.console;


private
{
    version (Windows)
    {
        import core.sys.windows.windows;
    }
    else version( Posix )
    {
        import core.sys.posix.unistd;
    }
    import rt.util.string;
}


struct Console
{
    Console opCall( in char[] val )
    {
        version( Windows )
        {
            DWORD count = void;
            assert(val.length <= uint.max, "val length cannot exceed uint.max");
            WriteFile( GetStdHandle( 0xfffffff4 ), val.ptr, cast(uint)val.length, &count, null );
        }
        else version( Posix )
        {
            write( 2, val.ptr, val.length );
        }
        return this;
    }


    Console opCall( ulong val )
    {
            char[20] tmp = void;
            return opCall( tmp.uintToString( val ) );
    }
}

__gshared Console console;
