/**
 * The exception module defines all system-level exceptions and provides a
 * mechanism to alter system-level error handling.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2013.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Sean Kelly and Jonathan M Davis
 * Source:    $(DRUNTIMESRC core/_exception.d)
 */
module core.exception;

import core.stdc.stdio;


/**
 * Thrown on a range error.
 */
class RangeError : Error
{
    @safe pure nothrow this( string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super( "Range violation", file, line, next );
    }
}

unittest
{
    {
        auto re = new RangeError();
        assert(re.file == __FILE__);
        assert(re.line == __LINE__ - 2);
        assert(re.next is null);
        assert(re.msg == "Range violation");
    }

    {
        auto re = new RangeError("hello", 42, new Exception("It's an Exception!"));
        assert(re.file == "hello");
        assert(re.line == 42);
        assert(re.next !is null);
        assert(re.msg == "Range violation");
    }
}


/**
 * Thrown on an assert error.
 */
class AssertError : Error
{
    @safe pure nothrow this( string file, size_t line )
    {
        this(cast(Throwable)null, file, line);
    }

    @safe pure nothrow this( Throwable next, string file = __FILE__, size_t line = __LINE__ )
    {
        this( "Assertion failure", file, line, next);
    }

    @safe pure nothrow this( string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super( msg, file, line, next );
    }
}

unittest
{
    {
        auto ae = new AssertError("hello", 42);
        assert(ae.file == "hello");
        assert(ae.line == 42);
        assert(ae.next is null);
        assert(ae.msg == "Assertion failure");
    }

    {
        auto ae = new AssertError(new Exception("It's an Exception!"));
        assert(ae.file == __FILE__);
        assert(ae.line == __LINE__ - 2);
        assert(ae.next !is null);
        assert(ae.msg == "Assertion failure");
    }

    {
        auto ae = new AssertError(new Exception("It's an Exception!"), "hello", 42);
        assert(ae.file == "hello");
        assert(ae.line == 42);
        assert(ae.next !is null);
        assert(ae.msg == "Assertion failure");
    }

    {
        auto ae = new AssertError("msg");
        assert(ae.file == __FILE__);
        assert(ae.line == __LINE__ - 2);
        assert(ae.next is null);
        assert(ae.msg == "msg");
    }

    {
        auto ae = new AssertError("msg", "hello", 42);
        assert(ae.file == "hello");
        assert(ae.line == 42);
        assert(ae.next is null);
        assert(ae.msg == "msg");
    }

    {
        auto ae = new AssertError("msg", "hello", 42, new Exception("It's an Exception!"));
        assert(ae.file == "hello");
        assert(ae.line == 42);
        assert(ae.next !is null);
        assert(ae.msg == "msg");
    }
}


/**
 * Thrown on finalize error.
 */
class FinalizeError : Error
{
    ClassInfo   info;

    @safe pure nothrow this( ClassInfo ci, Throwable next, string file = __FILE__, size_t line = __LINE__ )
    {
        this(ci, file, line, next);
    }

    @safe pure nothrow this( ClassInfo ci, string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super( "Finalization error", file, line, next );
        info = ci;
    }

    @safe override const string toString()
    {
        return "An exception was thrown while finalizing an instance of class " ~ info.name;
    }
}

unittest
{
    ClassInfo info = new ClassInfo;
    info.name = "testInfo";

    {
        auto fe = new FinalizeError(info);
        assert(fe.file == __FILE__);
        assert(fe.line == __LINE__ - 2);
        assert(fe.next is null);
        assert(fe.msg == "Finalization error");
        assert(fe.info == info);
    }

    {
        auto fe = new FinalizeError(info, new Exception("It's an Exception!"));
        assert(fe.file == __FILE__);
        assert(fe.line == __LINE__ - 2);
        assert(fe.next !is null);
        assert(fe.msg == "Finalization error");
        assert(fe.info == info);
    }

    {
        auto fe = new FinalizeError(info, "hello", 42);
        assert(fe.file == "hello");
        assert(fe.line == 42);
        assert(fe.next is null);
        assert(fe.msg == "Finalization error");
        assert(fe.info == info);
    }

    {
        auto fe = new FinalizeError(info, "hello", 42, new Exception("It's an Exception!"));
        assert(fe.file == "hello");
        assert(fe.line == 42);
        assert(fe.next !is null);
        assert(fe.msg == "Finalization error");
        assert(fe.info == info);
    }
}


/**
 * Thrown on hidden function error.
 */
class HiddenFuncError : Error
{
    @safe pure nothrow this( ClassInfo ci )
    {
        super( "Hidden method called for " ~ ci.name );
    }
}

unittest
{
    ClassInfo info = new ClassInfo;
    info.name = "testInfo";

    {
        auto hfe = new HiddenFuncError(info);
        assert(hfe.next is null);
        assert(hfe.msg == "Hidden method called for testInfo");
    }
}


/**
 * Thrown on an out of memory error.
 */
class OutOfMemoryError : Error
{
    @safe pure nothrow this(string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super( "Memory allocation failed", file, line, next );
    }

    @trusted override const string toString()
    {
        return msg ? (cast()super).toString() : "Memory allocation failed";
    }
}

unittest
{
    {
        auto oome = new OutOfMemoryError();
        assert(oome.file == __FILE__);
        assert(oome.line == __LINE__ - 2);
        assert(oome.next is null);
        assert(oome.msg == "Memory allocation failed");
    }

    {
        auto oome = new OutOfMemoryError("hello", 42, new Exception("It's an Exception!"));
        assert(oome.file == "hello");
        assert(oome.line == 42);
        assert(oome.next !is null);
        assert(oome.msg == "Memory allocation failed");
    }
}


/**
 * Thrown on an invalid memory operation.
 *
 * An invalid memory operation error occurs in circumstances when the garbage
 * collector has detected an operation it cannot reliably handle. The default
 * D GC is not re-entrant, so this can happen due to allocations done from
 * within finalizers called during a garbage collection cycle.
 */
class InvalidMemoryOperationError : Error
{
    @safe pure nothrow this(string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super( "Invalid memory operation", file, line, next );
    }

    @trusted override const string toString()
    {
        return msg ? (cast()super).toString() : "Invalid memory operation";
    }
}

unittest
{
    {
        auto oome = new InvalidMemoryOperationError();
        assert(oome.file == __FILE__);
        assert(oome.line == __LINE__ - 2);
        assert(oome.next is null);
        assert(oome.msg == "Invalid memory operation");
    }

    {
        auto oome = new InvalidMemoryOperationError("hello", 42, new Exception("It's an Exception!"));
        assert(oome.file == "hello");
        assert(oome.line == 42);
        assert(oome.next !is null);
        assert(oome.msg == "Invalid memory operation");
    }
}


/**
 * Thrown on a switch error.
 */
class SwitchError : Error
{
    @safe pure nothrow this( string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super( "No appropriate switch clause found", file, line, next );
    }
}

unittest
{
    {
        auto se = new SwitchError();
        assert(se.file == __FILE__);
        assert(se.line == __LINE__ - 2);
        assert(se.next is null);
        assert(se.msg == "No appropriate switch clause found");
    }

    {
        auto se = new SwitchError("hello", 42, new Exception("It's an Exception!"));
        assert(se.file == "hello");
        assert(se.line == 42);
        assert(se.next !is null);
        assert(se.msg == "No appropriate switch clause found");
    }
}


/**
 * Thrown on a unicode conversion error.
 */
class UnicodeException : Exception
{
    size_t idx;

    this( string msg, size_t idx, string file = __FILE__, size_t line = __LINE__, Throwable next = null ) @safe pure nothrow
    {
        super( msg, file, line, next );
        this.idx = idx;
    }
}

unittest
{
    {
        auto ue = new UnicodeException("msg", 2);
        assert(ue.file == __FILE__);
        assert(ue.line == __LINE__ - 2);
        assert(ue.next is null);
        assert(ue.msg == "msg");
        assert(ue.idx == 2);
    }

    {
        auto ue = new UnicodeException("msg", 2, "hello", 42, new Exception("It's an Exception!"));
        assert(ue.file == "hello");
        assert(ue.line == 42);
        assert(ue.next !is null);
        assert(ue.msg == "msg");
        assert(ue.idx == 2);
    }
}


///////////////////////////////////////////////////////////////////////////////
// Overrides
///////////////////////////////////////////////////////////////////////////////


// NOTE: One assert handler is used for all threads.  Thread-local
//       behavior should occur within the handler itself.  This delegate
//       is __gshared for now based on the assumption that it will only
//       set by the main thread during program initialization.
private __gshared AssertHandler _assertHandler = null;


/**
Gets/sets assert hander. null means the default handler is used.
*/
alias AssertHandler = void function(string file, size_t line, string msg) nothrow;

/// ditto
@property AssertHandler assertHandler() @trusted nothrow
{
    return _assertHandler;
}

/// ditto
@property void assertHandler(AssertHandler handler) @trusted nothrow
{
    _assertHandler = handler;
}

/**
 * Overrides the default assert hander with a user-supplied version.
 * $(RED Deprecated.
 *   Please use $(LREF assertHandler) instead.)
 *
 * Params:
 *  h = The new assert handler.  Set to null to use the default handler.
 */
deprecated void setAssertHandler( AssertHandler h ) @trusted nothrow
{
    assertHandler = h;
}


///////////////////////////////////////////////////////////////////////////////
// Overridable Callbacks
///////////////////////////////////////////////////////////////////////////////


/**
 * A callback for assert errors in D.  The user-supplied assert handler will
 * be called if one has been supplied, otherwise an AssertError will be thrown.
 *
 * Params:
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 */
extern (C) void onAssertError( string file = __FILE__, size_t line = __LINE__ ) nothrow
{
    if( _assertHandler is null )
        throw new AssertError( file, line );
    _assertHandler( file, line, null);
}


/**
 * A callback for assert errors in D.  The user-supplied assert handler will
 * be called if one has been supplied, otherwise an AssertError will be thrown.
 *
 * Params:
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 *  msg  = An error message supplied by the user.
 */
extern (C) void onAssertErrorMsg( string file, size_t line, string msg ) nothrow
{
    if( _assertHandler is null )
        throw new AssertError( msg, file, line );
    _assertHandler( file, line, msg );
}


/**
 * A callback for unittest errors in D.  The user-supplied unittest handler
 * will be called if one has been supplied, otherwise the error will be
 * written to stderr.
 *
 * Params:
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 *  msg  = An error message supplied by the user.
 */
extern (C) void onUnittestErrorMsg( string file, size_t line, string msg ) nothrow
{
    onAssertErrorMsg( file, line, msg );
}


///////////////////////////////////////////////////////////////////////////////
// Internal Error Callbacks
///////////////////////////////////////////////////////////////////////////////


/**
 * A callback for array bounds errors in D.  A RangeError will be thrown.
 *
 * Params:
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 *
 * Throws:
 *  RangeError.
 */
extern (C) void onRangeError( string file = __FILE__, size_t line = __LINE__ ) @safe pure nothrow
{
    throw new RangeError( file, line, null );
}


/**
 * A callback for finalize errors in D.  A FinalizeError will be thrown.
 *
 * Params:
 *  info = The ClassInfo instance for the object that failed finalization.
 *  e = The exception thrown during finalization.
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 *
 * Throws:
 *  FinalizeError.
 */
extern (C) void onFinalizeError( ClassInfo info, Exception e, string file = __FILE__, size_t line = __LINE__ ) @safe pure nothrow
{
    throw new FinalizeError( info, file, line, e );
}


/**
 * A callback for hidden function errors in D.  A HiddenFuncError will be
 * thrown.
 *
 * Throws:
 *  HiddenFuncError.
 */
extern (C) void onHiddenFuncError( Object o ) @safe pure nothrow
{
    throw new HiddenFuncError( o.classinfo );
}


/**
 * A callback for out of memory errors in D.  An OutOfMemoryError will be
 * thrown.
 *
 * Throws:
 *  OutOfMemoryError.
 */
extern (C) void onOutOfMemoryError() @trusted pure nothrow
{
    // NOTE: Since an out of memory condition exists, no allocation must occur
    //       while generating this object.
    throw cast(OutOfMemoryError) cast(void*) OutOfMemoryError.classinfo.init;
}


/**
 * A callback for invalid memory operations in D.  An
 * InvalidMemoryOperationError will be thrown.
 *
 * Throws:
 *  InvalidMemoryOperationError.
 */
extern (C) void onInvalidMemoryOperationError() @trusted pure nothrow
{
    // The same restriction applies as for onOutOfMemoryError. The GC is in an
    // undefined state, thus no allocation must occur while generating this object.
    throw cast(InvalidMemoryOperationError)
        cast(void*) InvalidMemoryOperationError.classinfo.init;
}


/**
 * A callback for switch errors in D.  A SwitchError will be thrown.
 *
 * Params:
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 *
 * Throws:
 *  SwitchError.
 */
extern (C) void onSwitchError( string file = __FILE__, size_t line = __LINE__ ) @safe pure nothrow
{
    throw new SwitchError( file, line, null );
}


/**
 * A callback for unicode errors in D.  A UnicodeException will be thrown.
 *
 * Params:
 *  msg = Information about the error.
 *  idx = String index where this error was detected.
 *  file = The name of the file that signaled this error.
 *  line = The line number on which this error occurred.
 *
 * Throws:
 *  UnicodeException.
 */
extern (C) void onUnicodeError( string msg, size_t idx, string file = __FILE__, size_t line = __LINE__ ) @safe pure
{
    throw new UnicodeException( msg, idx, file, line );
}

/***********************************
 * These functions must be defined for any D program linked
 * against this library.
 */
/+
extern (C) void onAssertError(string file, size_t line);
extern (C) void onAssertErrorMsg(string file, size_t line, string msg);
extern (C) void onUnittestErrorMsg(string file, size_t line, string msg);
extern (C) void onRangeError(string file, size_t line);
extern (C) void onHiddenFuncError(Object o);
extern (C) void onSwitchError(string file, size_t line);
+/

/***********************************
 * Function calls to these are generated by the compiler and inserted into
 * the object code.
 */

extern (C)
{
    // Use ModuleInfo to get file name for "m" versions

    /* One of these three is called upon an assert() fail.
     */
    void _d_assertm(ModuleInfo* m, uint line)
    {
        onAssertError(m.name, line);
    }

    void _d_assert_msg(string msg, string file, uint line)
    {
        onAssertErrorMsg(file, line, msg);
    }

    void _d_assert(string file, uint line)
    {
        onAssertError(file, line);
    }

    /* One of these three is called upon an assert() fail inside of a unittest block
     */
    void _d_unittestm(ModuleInfo* m, uint line)
    {
        _d_unittest(m.name, line);
    }

    void _d_unittest_msg(string msg, string file, uint line)
    {
        onUnittestErrorMsg(file, line, msg);
    }

    void _d_unittest(string file, uint line)
    {
        _d_unittest_msg("unittest failure", file, line);
    }

    /* Called when an array index is out of bounds
     */
    void _d_array_boundsm(ModuleInfo* m, uint line)
    {
        onRangeError(m.name, line);
    }

    void _d_array_bounds(string file, uint line)
    {
        onRangeError(file, line);
    }

    /* Called when a switch statement has no DefaultStatement, yet none of the cases match
     */
    void _d_switch_errorm(ModuleInfo* m, uint line)
    {
        onSwitchError(m.name, line);
    }

    void _d_switch_error(string file, uint line)
    {
        onSwitchError(file, line);
    }

  version (GNU)
  {
    void _d_hidden_func(Object o)
    {
        onHiddenFuncError(o);
    }
  }
  else
  {
    void _d_hidden_func()
    {
        Object o;
        version(D_InlineAsm_X86)
            asm
            {
                mov o, EAX;
            }
        else version(D_InlineAsm_X86_64)
            asm
            {
                mov o, RDI;
            }
        else
            static assert(0, "unknown os");

        onHiddenFuncError(o);
    }
  }
}


