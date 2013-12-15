/*
 * http://pubs.opengroup.org/onlinepubs/007908775/xsh/string.h.html
 */
import core.stdc.string;
import core.stdc.stdint;

extern(C)
{
	void* memcpy(void* dest, void* src, size_t count) pure nothrow
	{
		uint8_t* d = cast(uint8_t*)dest;
		uint8_t* s = cast(uint8_t*)src;

		for(size_t i = count; count; count--, d++, s++)
			*d = *s;

		return dest;
	}

	void* memmove(void* dest, void* src, size_t count) pure nothrow
	{
		uint8_t* d = cast(uint8_t*)dest;
		uint8_t* s = cast(uint8_t*)src;

		for(size_t i = count; count; count--, d++, s++)
		  *d = *s;

		return dest;
	}

	long memcmp(void* a, void* b, size_t n) pure nothrow
	{
		uint8_t* str_a = cast(uint8_t*)a;
		uint8_t* str_b = cast(uint8_t*)b;

		for(size_t i = 0; i < n; i++)
		{
			if(*str_a != *str_b)
				return *str_a - *str_b;

			str_a++;
			str_b++;
		}

		return 0;
	}

	void memset(void* addr, uint8_t val, uint32_t numBytes) pure nothrow
	{
		 uint8_t* data = cast(uint8_t*) addr;

		 for(int32_t i = 0; i < numBytes; i++){
			  data[i] = val;
		 }
	}

    void* memchr( void * ptr, int32_t value, size_t num)
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