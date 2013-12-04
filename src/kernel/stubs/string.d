/*
 * http://pubs.opengroup.org/onlinepubs/007908775/xsh/string.h.html
 */
import core.stdc.string;

extern(C)
{
	void* memcpy(void* dest, void* src, size_t count) pure nothrow
	{
		ubyte* d = cast(ubyte*)dest;
		ubyte* s = cast(ubyte*)src;

		for(size_t i = count; count; count--, d++, s++)
			*d = *s;

		return dest;
	}

	void* memmove(void* dest, void* src, size_t count) pure nothrow
	{
		ubyte* d = cast(ubyte*)dest;
		ubyte* s = cast(ubyte*)src;

		for(size_t i = count; count; count--, d++, s++)
		  *d = *s;

		return dest;
	}

	long memcmp(void* a, void* b, size_t n) pure nothrow
	{
		ubyte* str_a = cast(ubyte*)a;
		ubyte* str_b = cast(ubyte*)b;

		for(size_t i = 0; i < n; i++)
		{
			if(*str_a != *str_b)
				return *str_a - *str_b;

			str_a++;
			str_b++;
		}

		return 0;
	}

	void memset(void* addr, ubyte val, uint numBytes) pure nothrow
	{
		 ubyte* data = cast(ubyte*) addr;

		 for(int i = 0; i < numBytes; i++){
			  data[i] = val;
		 }
	}

    void* memchr( void * ptr, int value, size_t num)
	{
		return (cast(void*)0);
	}

	size_t strlen(immutable(char*) s) pure nothrow
	{
		char* c = cast(char*)s;
		size_t i = 0;
		for( ; *c != 0; i++, c++){}
		return i;
	}
}