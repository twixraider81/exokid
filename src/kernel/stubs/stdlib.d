/*
 * Diese Funktionen müssen wirklich implementiert werden
 * http://pubs.opengroup.org/onlinepubs/007908775/xsh/stdlib.h.html
 */
import core.stdc.stdlib;

extern(C)
{
	void* malloc( size_t size )
	{
		return null;
	}

	void* calloc( size_t num, size_t size )
	{
		return null;
	}

	void* realloc( void* p, size_t sz, uint ba = 0 ) pure nothrow
	{
		return null;
	}

	void free( void* p ) pure nothrow
    {
    }
}