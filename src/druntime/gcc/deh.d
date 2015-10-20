/* GDC -- D front-end for GCC
   Copyright (C) 2011, 2012 Free Software Foundation, Inc.

   GCC is free software; you can redistribute it and/or modify it under
   the terms of the GNU General Public License as published by the Free
   Software Foundation; either version 3, or (at your option) any later
   version.

   GCC is distributed in the hope that it will be useful, but WITHOUT ANY
   WARRANTY; without even the implied warranty of MERCHANTABILITY or
   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
   for more details.

   You should have received a copy of the GNU General Public License
   along with GCC; see the file COPYING3.  If not see
   <http://www.gnu.org/licenses/>.
*/

// This code is based on the libstdc++ exception handling routines.

module gcc.deh;

//Stub, called alot :/
version(BareMetal)
{
	extern (C) void _d_throw(Object obj) { }
	extern (C) int __gdc_personality_v0(int iversion, int actions, int exception_class, void *ue_header, void *context) { return 0; }
}
else:

import gcc.unwind;
import gcc.unwind_pe;
import gcc.builtins;

import core.memory;
import core.stdc.stdlib;

extern (C)
{
  int _d_isbaseof(ClassInfo, ClassInfo);
  void _d_createTrace(Object *);

}

version (GNU_ARM_EABI_Unwinder)
{
  const _Unwind_Exception_Class GDC_Exception_Class =
    ['G','N','U','C','D','_','_','\0'];
}
else
{
  // "GNUCD__\0"
  const _Unwind_Exception_Class GDC_Exception_Class = 0x005f5f4443554e47L;
}

struct Phase1Info
{
  _Unwind_Word handlerSwitchValue;
  ubyte *languageSpecificData;
  _Unwind_Ptr landingPad;
}

struct OurUnwindException
{
  version (GNU_ARM_EABI_Unwinder)
  {
    // Cached parsed handler data is stored elsewhere
    // DNotes: There is no ARM exception handling ABI for the D
    // programming language that mandates the use of
    // barrier_cache.bitpattern, but might as well use the space.
    void save(_Unwind_Context* context, ref Phase1Info info)
    {
      unwindHeader.barrier_cache.sp = _Unwind_GetGR (context, UNWIND_STACK_REG);
      with (unwindHeader.barrier_cache)
	{
	  //bitpattern[0] = cast(_uw) info.obj; // No need for this yet
	  bitpattern[1] = cast(_uw) info.handlerSwitchValue;
	  bitpattern[2] = cast(_uw) info.languageSpecificData;
	  bitpattern[3] = cast(_uw) info.landingPad;
	}
    }

    void restore(ref Phase1Info info)
    {
      with (unwindHeader.barrier_cache)
	{
	  info.handlerSwitchValue = cast(typeof(info.handlerSwitchValue))
	    bitpattern[1];
	  info.languageSpecificData = cast(typeof(info.languageSpecificData))
	    bitpattern[2];
	  info.landingPad = cast(typeof(info.landingPad))
	    bitpattern[3];
	}
    }
  }
  else
  {
    // Cache parsed handler data from the personality routine Phase 1
    // for Phase 2.
    Phase1Info cache;

    void save(_Unwind_Context* context, ref Phase1Info info)
    {
      cache = info;
    }

    void restore(ref Phase1Info info)
    {
      info = cache;
    }
  }

  // To place 'obj' behing unwindHeader.
  enum UNWIND_PAD = (Phase1Info.sizeof + Object.sizeof)
    % _Unwind_Exception.alignof;

  static if (UNWIND_PAD > 0)
    byte[UNWIND_PAD] _pad;

  Object obj;

  // The exception object must be directly behind unwindHeader.
  // (See build_exception_object.)
  static assert(unwindHeader.offsetof - obj.offsetof == obj.sizeof);

  // The generic exception header
  _Unwind_Exception unwindHeader;

  static OurUnwindException * fromHeader(_Unwind_Exception * p_ue)
  {
    return cast(OurUnwindException *)
      (cast(void*) p_ue - OurUnwindException.unwindHeader.offsetof);
  }
}

// D doesn't define these, so they are private for now.
private void __gdc_terminate()
{
  //  replaces std::terminate and terminating with a specific handler
  abort();
}

private void __gdc_unexpected()
{
}

private void __gdc_beginCatch(_Unwind_Exception *exc)
{
  // nothing
}

// This is called by the unwinder.

private extern (C) void
_gdc_cleanupException(_Unwind_Reason_Code code, _Unwind_Exception *exc)
{
  // If we haven't been caught by a foreign handler, then this is
  // some sort of unwind error.  In that case just die immediately.
  // _Unwind_DeleteException in the HP-UX IA64 libunwind library
  //  returns _URC_NO_REASON and not _URC_FOREIGN_EXCEPTION_CAUGHT
  // like the GCC _Unwind_DeleteException function does.
  if (code != _URC_FOREIGN_EXCEPTION_CAUGHT && code != _URC_NO_REASON)
    __gdc_terminate();

  OurUnwindException * p = OurUnwindException.fromHeader (exc);
  delete p;
}

// This is called by compiler-generated code for throw statements.
extern (C) public void
_d_throw(Object obj)
{
  OurUnwindException * exc = new OurUnwindException;

  static if ( is(typeof(exc.unwindHeader.exception_class = GDC_Exception_Class)) )
    exc.unwindHeader.exception_class = GDC_Exception_Class;
  else
    exc.unwindHeader.exception_class[] = GDC_Exception_Class[];

  exc.unwindHeader.exception_cleanup = & _gdc_cleanupException;
  exc.obj = obj;

  // Runtime now expects us to do this first before unwinding.
  _d_createTrace (cast(Object*)exc.obj);

  version (GNU_SjLj_Exceptions)
    _Unwind_SjLj_RaiseException (&exc.unwindHeader);
  else
    _Unwind_RaiseException (&exc.unwindHeader);

  // Some sort of unwinding error.  Note that terminate is a handler.
  __gdc_beginCatch (&exc.unwindHeader);
  __gdc_terminate();
}

// rethrow?

// extern(C) alias personalityImpl ...; would be nice
version (GNU_SjLj_Exceptions)
{
  extern (C)
  _Unwind_Reason_Code __gdc_personality_sj0(int iversion,
					    _Unwind_Action actions,
					    _Unwind_Exception_Class exception_class,
					    _Unwind_Exception *ue_header,
					    _Unwind_Context *context)
  {
    return personalityImpl (iversion, actions,
 			    exception_class != GDC_Exception_Class,
 			    ue_header, context);
  }

  private int __builtin_eh_return_data_regno(int x) { return x; }

}
else version (GNU_ARM_EABI_Unwinder)
{
  extern (C)
  _Unwind_Reason_Code __gdc_personality_v0(_Unwind_State state,
					   _Unwind_Exception* ue_header,
					   _Unwind_Context* context)
  {
    _Unwind_Action actions;

    switch (state & _US_ACTION_MASK)
      {
      case _US_VIRTUAL_UNWIND_FRAME:
	actions = _UA_SEARCH_PHASE;
	break;

      case _US_UNWIND_FRAME_STARTING:
	actions = _UA_CLEANUP_PHASE;
	if (!(state & _US_FORCE_UNWIND)
	    && ue_header.barrier_cache.sp == _Unwind_GetGR (context, UNWIND_STACK_REG))
	  actions |= _UA_HANDLER_FRAME;
	break;

      case _US_UNWIND_FRAME_RESUME:
	if (__gnu_unwind_frame (ue_header, context) != _URC_OK)
	  return _URC_FAILURE;
	return _URC_CONTINUE_UNWIND;

      default:
	abort();
      }
    actions |= state & _US_FORCE_UNWIND;

    // We don't know which runtime we're working with, so can't check this.
    // However the ABI routines hide this from us, and we don't actually need to knowa
    bool foreign_exception = false;

    return personalityImpl (1, actions, foreign_exception, ue_header, context);
  }
}
else
{
  extern (C)
  _Unwind_Reason_Code __gdc_personality_v0(int iversion,
					   _Unwind_Action actions,
					   _Unwind_Exception_Class exception_class,
					   _Unwind_Exception *ue_header,
					   _Unwind_Context *context)
  {
    return personalityImpl (iversion, actions,
 			    exception_class != GDC_Exception_Class,
 			    ue_header, context);
  }
}

private _Unwind_Reason_Code personalityImpl(int iversion,
					    _Unwind_Action actions,
					    bool foreign_exception,
					    _Unwind_Exception *ue_header,
					    _Unwind_Context *context)
{
  enum Found
  {
    nothing,
    terminate,
    cleanup,
    handler
  }

  Found found_type;
  lsda_header_info info;
  OurUnwindException * xh = OurUnwindException.fromHeader (ue_header);
  ubyte *p;
  ubyte *action_record;
  _Unwind_Ptr ip;
  Phase1Info phase1;
  int ip_before_insn = 0;

  version (GNU_ARM_EABI_Unwinder)
  {
    // The dwarf unwinder assumes the context structure holds things like the
    // function and LSDA pointers.  The ARM implementation caches these in
    // the exception header (UCB).  To avoid rewriting everything we make the
    // virtual IP register point at the UCB.
    ip = cast(_Unwind_Ptr) ue_header;
    _Unwind_SetGR (context, UNWIND_POINTER_REG, ip);
  }
  else
  {
    if (iversion != 1)
      return _URC_FATAL_PHASE1_ERROR;
  }

  // Shortcut for phase 2 found handler for domestic exception.
  if (actions == (_UA_CLEANUP_PHASE | _UA_HANDLER_FRAME) && ! foreign_exception)
    {
      xh.restore (phase1);
      found_type = (phase1.landingPad == 0 ? Found.terminate : Found.handler);
      goto install_context;
    }

  phase1.languageSpecificData = cast(ubyte *) _Unwind_GetLanguageSpecificData (context);

  // If no LSDA, then there are no handlers or cleanups.
  if (! phase1.languageSpecificData)
    {
      version (GNU_ARM_EABI_Unwinder)
	if (__gnu_unwind_frame (ue_header, context) != _URC_OK)
	  return _URC_FAILURE;
      return _URC_CONTINUE_UNWIND;
    }

  // Parse the LSDA header
  p = parse_lsda_header (context, phase1.languageSpecificData, &info);
  info.ttype_base = base_of_encoded_value (info.ttype_encoding, context);
  ip = _Unwind_GetIPInfo (context, &ip_before_insn);
  if (! ip_before_insn)
    --ip;
  phase1.landingPad = 0;
  action_record = null;
  phase1.handlerSwitchValue = 0;

  version (GNU_SjLj_Exceptions)
  {
    // The given "IP" is an index into the call-site table, with two
    // exceptions -- -1 means no-action, and 0 means terminate.  But
    // since we're using uleb128 values, we've not got random access
    // to the array.
    if (cast(int) ip < 0)
      return _URC_CONTINUE_UNWIND;
    else if (ip == 0)
      {
	// Fall through to set found_terminate.
      }
    else
      {
	_Unwind_Word cs_lp, cs_action;
	do
	  {
	    p = read_uleb128 (p, &cs_lp);
	    p = read_uleb128 (p, &cs_action);
	  }
	while (--ip);

	// Can never have null landing pad for sjlj -- that would have
	// been indicated by a -1 call site index.
	phase1.landingPad = cs_lp + 1;
	if (cs_action)
	  action_record = info.action_table + cs_action - 1;
	goto found_something;
      }
  }
  else
  {
    // Search the call-site table for the action associated with this IP.
    while (p < info.action_table)
      {
	_Unwind_Ptr cs_start, cs_len, cs_lp;
	_uleb128_t cs_action;

	// Note that all call-site encodings are "absolute" displacements.
	p = read_encoded_value (null, info.call_site_encoding, p, &cs_start);
	p = read_encoded_value (null, info.call_site_encoding, p, &cs_len);
	p = read_encoded_value (null, info.call_site_encoding, p, &cs_lp);
	p = read_uleb128 (p, &cs_action);

	// The table is sorted, so if we've passed the ip, stop.
	if (ip < info.Start + cs_start)
	  p = info.action_table;
	else if (ip < info.Start + cs_start + cs_len)
	  {
	    if (cs_lp)
	      phase1.landingPad = info.LPStart + cs_lp;
	    if (cs_action)
	      action_record = info.action_table + cs_action - 1;
	    goto found_something;
	  }
      }
  }

  // If ip is not present in the table, call terminate.  This is for
  // a destructor inside a cleanup, or a library routine the compiler
  // was not expecting to throw.
  found_type = Found.terminate;
  goto do_something;

 found_something:
  if (phase1.landingPad == 0)
    {
      // If ip is present, and has a null landing pad, there are
      // no cleanups or handlers to be run.
      found_type = Found.nothing;
    }
  else if (action_record == null)
    {
      // If ip is present, has a non-null landing pad, and a null
      // action table offset, then there are only cleanups present.
      // Cleanups use a zero switch value, as set above.
      found_type = Found.cleanup;
    }
  else
    {
      // Otherwise we have a catch handler or exception specification.

      _sleb128_t ar_filter, ar_disp;
      ClassInfo throw_type, catch_type;
      bool saw_cleanup = false;
      bool saw_handler = false;

      // During forced unwinding, we only run cleanups.  With a foreign
      // exception class, there's no exception type.
      // ??? What to do about GNU Java and GNU Ada exceptions.

      if ((actions & _UA_FORCE_UNWIND) || foreign_exception)
	throw_type = null;
      else
	throw_type = xh.obj.classinfo;

      while (1)
	{
	  p = action_record;
	  p = read_sleb128 (p, &ar_filter);
	  read_sleb128 (p, &ar_disp);

	  if (ar_filter == 0)
	    {
	      // Zero filter values are cleanups.
	      saw_cleanup = true;
	    }
	  else if (ar_filter > 0)
	    {
	      // Positive filter values are handlers.
	      catch_type = get_classinfo_entry (&info, ar_filter);

	      // Null catch type is a catch-all handler; we can catch foreign
	      // exceptions with this.  Otherwise we must match types.
	      // D Note: will be performing dynamic cast twice, potentially
	      // Once here and once at the landing pad .. unless we cached
	      // here and had a begin_catch call.
	      if (! catch_type
		  || (throw_type
		      && _d_isbaseof (throw_type, catch_type)))
		{
		  saw_handler = true;
		  break;
		}
	    }
	  else
	    {
	      // D Note: we don't have these...
	      break;
	    }

	  if (ar_disp == 0)
	    break;
	  action_record = p + ar_disp;
	}

      if (saw_handler)
	{
	  phase1.handlerSwitchValue = ar_filter;
	  found_type = Found.handler;
	}
      else
	found_type = (saw_cleanup ? Found.cleanup : Found.nothing);
    }

 do_something:
  if (found_type == Found.nothing)
    {
      version (GNU_ARM_EABI_Unwinder)
	if (__gnu_unwind_frame (ue_header, context) != _URC_OK)
	  return _URC_FAILURE;
      return _URC_CONTINUE_UNWIND;
    }

  if (actions & _UA_SEARCH_PHASE)
    {
      if (found_type == Found.cleanup)
	{
	  version (GNU_ARM_EABI_Unwinder)
	    if (__gnu_unwind_frame (ue_header, context) != _URC_OK)
	      return _URC_FAILURE;
	  return _URC_CONTINUE_UNWIND;
	}

      // For domestic exceptions, we cache data from phase 1 for phase 2.
      if (! foreign_exception)
	xh.save (context, phase1);
      return _URC_HANDLER_FOUND;
    }

 install_context:

  // We can't use any of the deh routines with foreign exceptions,
  // because they all expect ue_header to be an OurUnwindException.
  // So in that case, call terminate or unexpected directly.
  if ((actions & _UA_FORCE_UNWIND) || foreign_exception)
    {
      if (found_type == Found.terminate)
	__gdc_terminate();
      else if (phase1.handlerSwitchValue < 0)
	__gdc_unexpected();
    }
  else
    {
      if (found_type == Found.terminate)
	{
	  __gdc_beginCatch (&xh.unwindHeader);
	  __gdc_terminate();
	}

      if (phase1.handlerSwitchValue < 0)
	{
	  parse_lsda_header (context, phase1.languageSpecificData, &info);
	  info.ttype_base = base_of_encoded_value (info.ttype_encoding, context);
	}
    }

  static if (is(typeof(__builtin_extend_pointer)))
    // For targets with pointers smaller than the word size, we must extend the
    // pointer, and this extension is target dependent.
    _Unwind_SetGR (context, __builtin_eh_return_data_regno (0),
		   __builtin_extend_pointer (&xh.unwindHeader));
  else
    _Unwind_SetGR (context, __builtin_eh_return_data_regno (0),
		   cast(_Unwind_Ptr) &xh.unwindHeader);

  _Unwind_SetGR (context, __builtin_eh_return_data_regno (1),
		 phase1.handlerSwitchValue);
  _Unwind_SetIP (context, phase1.landingPad);

  return _URC_INSTALL_CONTEXT;
}

struct lsda_header_info
{
  _Unwind_Ptr Start;
  _Unwind_Ptr LPStart;
  _Unwind_Ptr ttype_base;
  ubyte *TType;
  ubyte *action_table;
  ubyte ttype_encoding;
  ubyte call_site_encoding;
}

private ubyte *
parse_lsda_header (_Unwind_Context *context, ubyte *p,
		   lsda_header_info *info)
{
  _uleb128_t tmp;
  ubyte lpstart_encoding;

  info.Start = (context ? _Unwind_GetRegionStart (context) : 0);

  // Find @LPStart, the base to which landing pad offsets are relative.
  lpstart_encoding = *p++;
  if (lpstart_encoding != DW_EH_PE_omit)
    p = read_encoded_value (context, lpstart_encoding, p, &info.LPStart);
  else
    info.LPStart = info.Start;

  // Find @TType, the base of the handler and exception spec type data.
  info.ttype_encoding = *p++;
  if (info.ttype_encoding != DW_EH_PE_omit)
    {
      version (GNU_ARM_EABI_Unwinder)
      {
	// Older ARM EABI toolchains set this value incorrectly, so use a
	// hardcoded OS-specific format.
	info.ttype_encoding = _TTYPE_ENCODING;
      }
      p = read_uleb128 (p, &tmp);
      info.TType = p + tmp;
    }
  else
    info.TType = null;

  // The encoding and length of the call-site table; the action table
  // immediately follows.
  info.call_site_encoding = *p++;
  p = read_uleb128 (p, &tmp);
  info.action_table = p + tmp;

  return p;
}

private ClassInfo
get_classinfo_entry (lsda_header_info *info, _Unwind_Word i)
{
  _Unwind_Ptr ptr;

  i *= size_of_encoded_value (info.ttype_encoding);
  read_encoded_value_with_base (info.ttype_encoding, info.ttype_base,
				info.TType - i, &ptr);

  return cast(ClassInfo)cast(void *)(ptr);
}

