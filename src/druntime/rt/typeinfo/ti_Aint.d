/**
 * TypeInfo support code.
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.typeinfo.ti_Aint;

private import core.stdc.string;
private import rt.util.hash;

// int[]

class TypeInfo_Ai : TypeInfo_Array
{
    override bool opEquals(Object o) { return TypeInfo.opEquals(o); }

    override string toString() const { return "int[]"; }

    override size_t getHash(in void* p) @trusted const
    {
        int[] s = *cast(int[]*)p;
        return hashOf(s.ptr, s.length * int.sizeof);
    }

    override bool equals(in void* p1, in void* p2) const
    {
        int[] s1 = *cast(int[]*)p1;
        int[] s2 = *cast(int[]*)p2;

        return s1.length == s2.length &&
               memcmp(cast(void *)s1, cast(void *)s2, s1.length * int.sizeof) == 0;
    }

    override int compare(in void* p1, in void* p2) const
    {
        int[] s1 = *cast(int[]*)p1;
        int[] s2 = *cast(int[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int result = s1[u] - s2[u];
            if (result)
                return result;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    override @property inout(TypeInfo) next() inout
    {
        return cast(inout)typeid(int);
    }
}

unittest
{
    int[][] a = [[5,3,8,7], [2,5,3,8,7]];
    a.sort;
    assert(a == [[2,5,3,8,7], [5,3,8,7]]);

    a = [[5,3,8,7], [5,3,8]];
    a.sort;
    assert(a == [[5,3,8], [5,3,8,7]]);
}

// uint[]

class TypeInfo_Ak : TypeInfo_Ai
{
    override string toString() const { return "uint[]"; }

    override int compare(in void* p1, in void* p2) const
    {
        uint[] s1 = *cast(uint[]*)p1;
        uint[] s2 = *cast(uint[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int result = s1[u] - s2[u];
            if (result)
                return result;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    override @property inout(TypeInfo) next() inout
    {
        return cast(inout)typeid(uint);
    }
}

// dchar[]

class TypeInfo_Aw : TypeInfo_Ak
{
    override string toString() const { return "dchar[]"; }

    override @property inout(TypeInfo) next() inout
    {
        return cast(inout)typeid(dchar);
    }
}
