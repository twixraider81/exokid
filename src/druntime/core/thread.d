﻿/**
 * The thread module provides support for thread creation and management.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Sean Kelly, Walter Bright, Alex Rønne Petersen, Martin Nowak
 * Source:    $(DRUNTIMESRC core/_thread.d)
 */

module core.thread;

version(BareMetal) {}
else:

public import core.time; // for Duration
import core.exception : onOutOfMemoryError;
static import rt.tlsgc;

// this should be true for most architectures
version( GNU_StackGrowsDown )
    version = StackGrowsDown;

/**
 * Returns the process ID of the calling process, which is guaranteed to be
 * unique on the system. This call is always successful.
 *
 * Example:
 * ---
 * writefln("Current process id: %s", getpid());
 * ---
 */
version(Posix)
{
    alias core.sys.posix.unistd.getpid getpid;
}
else version (Windows)
{
    alias core.sys.windows.windows.GetCurrentProcessId getpid;
}


///////////////////////////////////////////////////////////////////////////////
// Thread and Fiber Exceptions
///////////////////////////////////////////////////////////////////////////////


/**
 * Base class for thread exceptions.
 */
class ThreadException : Exception
{
    @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }

    @safe pure nothrow this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, next);
    }
}


/**
 * Base class for fiber exceptions.
 */
class FiberException : Exception
{
    @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }

    @safe pure nothrow this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, next);
    }
}


private
{
    import core.sync.mutex;
    import core.atomic;

    //
    // from core.memory
    //
    extern (C) void  gc_enable();
    extern (C) void  gc_disable();
    extern (C) void* gc_malloc(size_t sz, uint ba = 0);

    //
    // from core.stdc.string
    //
    extern (C) void* memcpy(void*, const void*, size_t);

    //
    // exposed by compiler runtime
    //
    extern (C) void  rt_moduleTlsCtor();
    extern (C) void  rt_moduleTlsDtor();

    alias void delegate() gc_atom;
    extern (C) void function(scope gc_atom) gc_atomic;
}


///////////////////////////////////////////////////////////////////////////////
// Thread Entry Point and Signal Handlers
///////////////////////////////////////////////////////////////////////////////


version( Windows )
{
    private
    {
        import core.stdc.stdint : uintptr_t; // for _beginthreadex decl below
        import core.stdc.stdlib;             // for malloc, atexit
        import core.sys.windows.windows;
        import core.sys.windows.threadaux;   // for OpenThreadHandle

        const DWORD TLS_OUT_OF_INDEXES  = 0xFFFFFFFF;
        const CREATE_SUSPENDED = 0x00000004;

        extern (Windows) alias uint function(void*) btex_fptr;
        extern (C) uintptr_t _beginthreadex(void*, uint, btex_fptr, void*, uint, uint*);

        //
        // Entry point for Windows threads
        //
        extern (Windows) uint thread_entryPoint( void* arg )
        {
            Thread  obj = cast(Thread) arg;
            assert( obj );

            assert( obj.m_curr is &obj.m_main );
            obj.m_main.bstack = getStackBottom();
            obj.m_main.tstack = obj.m_main.bstack;
            obj.m_tlsgcdata = rt.tlsgc.init();

            Thread.setThis( obj );
            //Thread.add( obj );
            scope( exit )
            {
                Thread.remove( obj );
            }
            Thread.add( &obj.m_main );

            // NOTE: No GC allocations may occur until the stack pointers have
            //       been set and Thread.getThis returns a valid reference to
            //       this thread object (this latter condition is not strictly
            //       necessary on Windows but it should be followed for the
            //       sake of consistency).

            // TODO: Consider putting an auto exception object here (using
            //       alloca) forOutOfMemoryError plus something to track
            //       whether an exception is in-flight?

            void append( Throwable t )
            {
                if( obj.m_unhandled is null )
                    obj.m_unhandled = t;
                else
                {
                    Throwable last = obj.m_unhandled;
                    while( last.next !is null )
                        last = last.next;
                    last.next = t;
                }
            }

            version( D_InlineAsm_X86 )
            {
                asm { fninit; }
            }

            try
            {
                rt_moduleTlsCtor();
                try
                {
                    obj.run();
                }
                catch( Throwable t )
                {
                    append( t );
                }
                rt_moduleTlsDtor();
            }
            catch( Throwable t )
            {
                append( t );
            }
            return 0;
        }


        HANDLE GetCurrentThreadHandle()
        {
            const uint DUPLICATE_SAME_ACCESS = 0x00000002;

            HANDLE curr = GetCurrentThread(),
                   proc = GetCurrentProcess(),
                   hndl;

            DuplicateHandle( proc, curr, proc, &hndl, 0, TRUE, DUPLICATE_SAME_ACCESS );
            return hndl;
        }
    }
}
else version( Posix )
{
    private
    {
        import core.stdc.errno;
        import core.sys.posix.semaphore;
        import core.sys.posix.stdlib; // for malloc, valloc, free, atexit
        import core.sys.posix.pthread;
        import core.sys.posix.signal;
        import core.sys.posix.time;

        version( OSX )
        {
            import core.sys.osx.mach.thread_act;
            extern (C) mach_port_t pthread_mach_thread_np(pthread_t);
        }

        version( GNU )
        {
            import gcc.builtins;

            extern (C)
            {
                extern size_t _tlsstart;
                extern size_t _tlsend;
            }
        }

        //
        // Entry point for POSIX threads
        //
        extern (C) void* thread_entryPoint( void* arg )
        {
            version (Shared)
            {
                import rt.sections;
                Thread obj = cast(Thread)(cast(void**)arg)[0];
                auto loadedLibraries = (cast(void**)arg)[1];
                .free(arg);
            }
            else
            {
                Thread obj = cast(Thread)arg;
            }
            assert( obj );

            assert( obj.m_curr is &obj.m_main );
            obj.m_main.bstack = getStackBottom();
            obj.m_main.tstack = obj.m_main.bstack;
            obj.m_tlsgcdata = rt.tlsgc.init();
            version (GNU)
            {
                auto pstart = cast(void*) &_tlsstart;
                auto pend   = cast(void*) &_tlsend;
                obj.m_tls = pstart[0 .. pend - pstart];
            }

            obj.m_isRunning = true;
            Thread.setThis( obj );
            //Thread.add( obj );
            scope( exit )
            {
                // NOTE: isRunning should be set to false after the thread is
                //       removed or a double-removal could occur between this
                //       function and thread_suspendAll.
                Thread.remove( obj );
                obj.m_isRunning = false;
            }
            Thread.add( &obj.m_main );

            static extern (C) void thread_cleanupHandler( void* arg ) nothrow
            {
                Thread  obj = cast(Thread) arg;
                assert( obj );

                // NOTE: If the thread terminated abnormally, just set it as
                //       not running and let thread_suspendAll remove it from
                //       the thread list.  This is safer and is consistent
                //       with the Windows thread code.
                obj.m_isRunning = false;
            }

            // NOTE: Using void to skip the initialization here relies on
            //       knowledge of how pthread_cleanup is implemented.  It may
            //       not be appropriate for all platforms.  However, it does
            //       avoid the need to link the pthread module.  If any
            //       implementation actually requires default initialization
            //       then pthread_cleanup should be restructured to maintain
            //       the current lack of a link dependency.
            static if( __traits( compiles, pthread_cleanup ) )
            {
                pthread_cleanup cleanup = void;
                cleanup.push( &thread_cleanupHandler, cast(void*) obj );
            }
            else static if( __traits( compiles, pthread_cleanup_push ) )
            {
                pthread_cleanup_push( &thread_cleanupHandler, cast(void*) obj );
            }
            else
            {
                static assert( false, "Platform not supported." );
            }

            // NOTE: No GC allocations may occur until the stack pointers have
            //       been set and Thread.getThis returns a valid reference to
            //       this thread object (this latter condition is not strictly
            //       necessary on Windows but it should be followed for the
            //       sake of consistency).

            // TODO: Consider putting an auto exception object here (using
            //       alloca) forOutOfMemoryError plus something to track
            //       whether an exception is in-flight?

            void append( Throwable t )
            {
                if( obj.m_unhandled is null )
                    obj.m_unhandled = t;
                else
                {
                    Throwable last = obj.m_unhandled;
                    while( last.next !is null )
                        last = last.next;
                    last.next = t;
                }
            }

            try
            {
                version (Shared) inheritLoadedLibraries(loadedLibraries);
                rt_moduleTlsCtor();
                try
                {
                    obj.run();
                }
                catch( Throwable t )
                {
                    append( t );
                }
                rt_moduleTlsDtor();
                version (Shared) cleanupLoadedLibraries();
            }
            catch( Throwable t )
            {
                append( t );
            }

            // NOTE: Normal cleanup is handled by scope(exit).

            static if( __traits( compiles, pthread_cleanup ) )
            {
                cleanup.pop( 0 );
            }
            else static if( __traits( compiles, pthread_cleanup_push ) )
            {
                pthread_cleanup_pop( 0 );
            }

            return null;
        }


        //
        // Used to track the number of suspended threads
        //
        __gshared sem_t suspendCount;


        extern (C) void thread_suspendHandler( int sig )
        in
        {
            assert( sig == SIGUSR1 );
        }
        body
        {
            void op(void* sp)
            {
                // NOTE: Since registers are being pushed and popped from the
                //       stack, any other stack data used by this function should
                //       be gone before the stack cleanup code is called below.
                Thread  obj = Thread.getThis();

                // NOTE: The thread reference returned by getThis is set within
                //       the thread startup code, so it is possible that this
                //       handler may be called before the reference is set.  In
                //       this case it is safe to simply suspend and not worry
                //       about the stack pointers as the thread will not have
                //       any references to GC-managed data.
                if( obj && !obj.m_lock )
                {
                    obj.m_curr.tstack = getStackTop();
                }

                sigset_t    sigres = void;
                int         status;

                status = sigfillset( &sigres );
                assert( status == 0 );

                status = sigdelset( &sigres, SIGUSR2 );
                assert( status == 0 );

                status = sem_post( &suspendCount );
                assert( status == 0 );

                sigsuspend( &sigres );

                if( obj && !obj.m_lock )
                {
                    obj.m_curr.tstack = obj.m_curr.bstack;
                }
            }

            callWithStackShell(&op);
        }


        extern (C) void thread_resumeHandler( int sig )
        in
        {
            assert( sig == SIGUSR2 );
        }
        body
        {

        }
    }
}
else
{
    // NOTE: This is the only place threading versions are checked.  If a new
    //       version is added, the module code will need to be searched for
    //       places where version-specific code may be required.  This can be
    //       easily accomlished by searching for 'Windows' or 'Posix'.
    static assert( false, "Unknown threading implementation." );
}


///////////////////////////////////////////////////////////////////////////////
// Thread
///////////////////////////////////////////////////////////////////////////////


/**
 * This class encapsulates all threading functionality for the D
 * programming language.  As thread manipulation is a required facility
 * for garbage collection, all user threads should derive from this
 * class, and instances of this class should never be explicitly deleted.
 * A new thread may be created using either derivation or composition, as
 * in the following example.
 *
 * Example:
 * ----------------------------------------------------------------------------
 *
 * class DerivedThread : Thread
 * {
 *     this()
 *     {
 *         super( &run );
 *     }
 *
 * private :
 *     void run()
 *     {
 *         printf( "Derived thread running.\n" );
 *     }
 * }
 *
 * void threadFunc()
 * {
 *     printf( "Composed thread running.\n" );
 * }
 *
 * // create instances of each type
 * Thread derived = new DerivedThread();
 * Thread composed = new Thread( &threadFunc );
 *
 * // start both threads
 * derived.start();
 * composed.start();
 *
 * ----------------------------------------------------------------------------
 */
class Thread
{
    ///////////////////////////////////////////////////////////////////////////
    // Initialization
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Initializes a thread object which is associated with a static
     * D function.
     *
     * Params:
     *  fn = The thread function.
     *  sz = The stack size for this thread.
     *
     * In:
     *  fn must not be null.
     */
    this( void function() fn, size_t sz = 0 )
    in
    {
        assert( fn );
    }
    body
    {
        this();
        m_fn   = fn;
        m_sz   = sz;
        m_call = Call.FN;
        m_curr = &m_main;
    }


    /**
     * Initializes a thread object which is associated with a dynamic
     * D function.
     *
     * Params:
     *  dg = The thread function.
     *  sz = The stack size for this thread.
     *
     * In:
     *  dg must not be null.
     */
    this( void delegate() dg, size_t sz = 0 )
    in
    {
        assert( dg );
    }
    body
    {
        this();
        m_dg   = dg;
        m_sz   = sz;
        m_call = Call.DG;
        m_curr = &m_main;
    }


    /**
     * Cleans up any remaining resources used by this object.
     */
    ~this()
    {
        if( m_addr == m_addr.init )
        {
            return;
        }

        version( Windows )
        {
            m_addr = m_addr.init;
            CloseHandle( m_hndl );
            m_hndl = m_hndl.init;
        }
        else version( Posix )
        {
            pthread_detach( m_addr );
            m_addr = m_addr.init;
        }
        version( OSX )
        {
            m_tmach = m_tmach.init;
        }
        rt.tlsgc.destroy( m_tlsgcdata );
        m_tlsgcdata = null;
    }


    ///////////////////////////////////////////////////////////////////////////
    // General Actions
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Starts the thread and invokes the function or delegate passed upon
     * construction.
     *
     * In:
     *  This routine may only be called once per thread instance.
     *
     * Throws:
     *  ThreadException if the thread fails to start.
     */
    final void start()
    in
    {
        assert( !next && !prev );
    }
    body
    {
        auto wasThreaded  = multiThreadedFlag;
        multiThreadedFlag = true;
        scope( failure )
        {
            if( !wasThreaded )
                multiThreadedFlag = false;
        }

        version( Windows ) {} else
        version( Posix )
        {
            pthread_attr_t  attr;

            if( pthread_attr_init( &attr ) )
                throw new ThreadException( "Error initializing thread attributes" );
            if( m_sz && pthread_attr_setstacksize( &attr, m_sz ) )
                throw new ThreadException( "Error initializing thread stack size" );
            if( pthread_attr_setdetachstate( &attr, PTHREAD_CREATE_JOINABLE ) )
                throw new ThreadException( "Error setting thread joinable" );
        }

        version( Windows )
        {
            // NOTE: If a thread is just executing DllMain()
            //       while another thread is started here, it holds an OS internal
            //       lock that serializes DllMain with CreateThread. As the code
            //       might request a synchronization on slock (e.g. in thread_findByAddr()),
            //       we cannot hold that lock while creating the thread without
            //       creating a deadlock
            //
            // Solution: Create the thread in suspended state and then
            //       add and resume it with slock acquired
            assert(m_sz <= uint.max, "m_sz must be less than or equal to uint.max");
            m_hndl = cast(HANDLE) _beginthreadex( null, cast(uint) m_sz, &thread_entryPoint, cast(void*) this, CREATE_SUSPENDED, &m_addr );
            if( cast(size_t) m_hndl == 0 )
                throw new ThreadException( "Error creating thread" );
        }

        // NOTE: The starting thread must be added to the global thread list
        //       here rather than within thread_entryPoint to prevent a race
        //       with the main thread, which could finish and terminat the
        //       app without ever knowing that it should have waited for this
        //       starting thread.  In effect, not doing the add here risks
        //       having thread being treated like a daemon thread.
        synchronized( slock )
        {
            version( Windows )
            {
                if( ResumeThread( m_hndl ) == -1 )
                    throw new ThreadException( "Error resuming thread" );
            }
            else version( Posix )
            {
                // NOTE: This is also set to true by thread_entryPoint, but set it
                //       here as well so the calling thread will see the isRunning
                //       state immediately.
                m_isRunning = true;
                scope( failure ) m_isRunning = false;

                version (Shared)
                {
                    import rt.sections;
                    auto libs = pinLoadedLibraries();
                    auto ps = cast(void**).malloc(2 * size_t.sizeof);
                    if (ps is null) onOutOfMemoryError();
                    ps[0] = cast(void*)this;
                    ps[1] = cast(void*)libs;
                    if( pthread_create( &m_addr, &attr, &thread_entryPoint, ps ) != 0 )
                    {
                        unpinLoadedLibraries(libs);
                        .free(ps);
                        throw new ThreadException( "Error creating thread" );
                    }
                }
                else
                {
                    if( pthread_create( &m_addr, &attr, &thread_entryPoint, cast(void*) this ) != 0 )
                        throw new ThreadException( "Error creating thread" );
                }
            }
            version( OSX )
            {
                m_tmach = pthread_mach_thread_np( m_addr );
                if( m_tmach == m_tmach.init )
                    throw new ThreadException( "Error creating thread" );
            }

            // NOTE: when creating threads from inside a DLL, DllMain(THREAD_ATTACH)
            //       might be called before ResumeThread returns, but the dll
            //       helper functions need to know whether the thread is created
            //       from the runtime itself or from another DLL or the application
            //       to just attach to it
            //       as a consequence, the new Thread object is added before actual
            //       creation of the thread. There should be no problem with the GC
            //       calling thread_suspendAll, because of the slock synchronization
            //
            // VERIFY: does this actually also apply to other platforms?
            add( this );
        }
    }


    /**
     * Waits for this thread to complete.  If the thread terminated as the
     * result of an unhandled exception, this exception will be rethrown.
     *
     * Params:
     *  rethrow = Rethrow any unhandled exception which may have caused this
     *            thread to terminate.
     *
     * Throws:
     *  ThreadException if the operation fails.
     *  Any exception not handled by the joined thread.
     *
     * Returns:
     *  Any exception not handled by this thread if rethrow = false, null
     *  otherwise.
     */
    final Throwable join( bool rethrow = true )
    {
        version( Windows )
        {
            if( WaitForSingleObject( m_hndl, INFINITE ) != WAIT_OBJECT_0 )
                throw new ThreadException( "Unable to join thread" );
            // NOTE: m_addr must be cleared before m_hndl is closed to avoid
            //       a race condition with isRunning. The operation is done
            //       with atomicStore to prevent compiler reordering.
            atomicStore!(MemoryOrder.raw)(*cast(shared)&m_addr, m_addr.init);
            CloseHandle( m_hndl );
            m_hndl = m_hndl.init;
        }
        else version( Posix )
        {
            if( pthread_join( m_addr, null ) != 0 )
                throw new ThreadException( "Unable to join thread" );
            // NOTE: pthread_join acts as a substitute for pthread_detach,
            //       which is normally called by the dtor.  Setting m_addr
            //       to zero ensures that pthread_detach will not be called
            //       on object destruction.
            m_addr = m_addr.init;
        }
        if( m_unhandled )
        {
            if( rethrow )
                throw m_unhandled;
            return m_unhandled;
        }
        return null;
    }


    ///////////////////////////////////////////////////////////////////////////
    // General Properties
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Gets the user-readable label for this thread.
     *
     * Returns:
     *  The name of this thread.
     */
    final @property string name()
    {
        synchronized( this )
        {
            return m_name;
        }
    }


    /**
     * Sets the user-readable label for this thread.
     *
     * Params:
     *  val = The new name of this thread.
     */
    final @property void name( string val )
    {
        synchronized( this )
        {
            m_name = val;
        }
    }


    /**
     * Gets the daemon status for this thread.  While the runtime will wait for
     * all normal threads to complete before tearing down the process, daemon
     * threads are effectively ignored and thus will not prevent the process
     * from terminating.  In effect, daemon threads will be terminated
     * automatically by the OS when the process exits.
     *
     * Returns:
     *  true if this is a daemon thread.
     */
    final @property bool isDaemon()
    {
        synchronized( this )
        {
            return m_isDaemon;
        }
    }


    /**
     * Sets the daemon status for this thread.  While the runtime will wait for
     * all normal threads to complete before tearing down the process, daemon
     * threads are effectively ignored and thus will not prevent the process
     * from terminating.  In effect, daemon threads will be terminated
     * automatically by the OS when the process exits.
     *
     * Params:
     *  val = The new daemon status for this thread.
     */
    final @property void isDaemon( bool val )
    {
        synchronized( this )
        {
            m_isDaemon = val;
        }
    }


    /**
     * Tests whether this thread is running.
     *
     * Returns:
     *  true if the thread is running, false if not.
     */
    final @property bool isRunning()
    {
        if( m_addr == m_addr.init )
        {
            return false;
        }

        version( Windows )
        {
            uint ecode = 0;
            GetExitCodeThread( m_hndl, &ecode );
            return ecode == STILL_ACTIVE;
        }
        else version( Posix )
        {
            // NOTE: It should be safe to access this value without
            //       memory barriers because word-tearing and such
            //       really isn't an issue for boolean values.
            return m_isRunning;
        }
    }


    ///////////////////////////////////////////////////////////////////////////
    // Thread Priority Actions
    ///////////////////////////////////////////////////////////////////////////


    /**
     * The minimum scheduling priority that may be set for a thread.  On
     * systems where multiple scheduling policies are defined, this value
     * represents the minimum valid priority for the scheduling policy of
     * the process.
     */
    __gshared const int PRIORITY_MIN;


    /**
     * The maximum scheduling priority that may be set for a thread.  On
     * systems where multiple scheduling policies are defined, this value
     * represents the maximum valid priority for the scheduling policy of
     * the process.
     */
    __gshared const int PRIORITY_MAX;


    /**
     * The default scheduling priority that is set for a thread.  On
     * systems where multiple scheduling policies are defined, this value
     * represents the default priority for the scheduling policy of
     * the process.
     */
    __gshared const int PRIORITY_DEFAULT;


    /**
     * Gets the scheduling priority for the associated thread.
     *
     * Returns:
     *  The scheduling priority of this thread.
     */
    final @property int priority()
    {
        version( Windows )
        {
            return GetThreadPriority( m_hndl );
        }
        else version( Posix )
        {
            int         policy;
            sched_param param;

            if( pthread_getschedparam( m_addr, &policy, &param ) )
                throw new ThreadException( "Unable to get thread priority" );
            return param.sched_priority;
        }
    }


    /**
     * Sets the scheduling priority for the associated thread.
     *
     * Params:
     *  val = The new scheduling priority of this thread.
     */
    final @property void priority( int val )
    in
    {
        assert(val >= PRIORITY_MIN);
        assert(val <= PRIORITY_MAX);
    }
    body
    {
        version( Windows )
        {
            if( !SetThreadPriority( m_hndl, val ) )
                throw new ThreadException( "Unable to set thread priority" );
        }
        else version( Posix )
        {
            static if( __traits( compiles, pthread_setschedprio ) )
            {
                if( pthread_setschedprio( m_addr, val ) )
                    throw new ThreadException( "Unable to set thread priority" );
            }
            else
            {
                // NOTE: pthread_setschedprio is not implemented on OSX or FreeBSD, so use
                //       the more complicated get/set sequence below.
                int         policy;
                sched_param param;

                if( pthread_getschedparam( m_addr, &policy, &param ) )
                    throw new ThreadException( "Unable to set thread priority" );
                param.sched_priority = val;
                if( pthread_setschedparam( m_addr, policy, &param ) )
                    throw new ThreadException( "Unable to set thread priority" );
            }
        }
    }


    unittest
    {
        auto thr = Thread.getThis();
        immutable prio = thr.priority;
        scope (exit) thr.priority = prio;

        assert(prio == PRIORITY_DEFAULT);
        assert(prio >= PRIORITY_MIN && prio <= PRIORITY_MAX);
        thr.priority = PRIORITY_MIN;
        assert(thr.priority == PRIORITY_MIN);
        thr.priority = PRIORITY_MAX;
        assert(thr.priority == PRIORITY_MAX);
    }

    ///////////////////////////////////////////////////////////////////////////
    // Actions on Calling Thread
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Suspends the calling thread for at least the supplied period.  This may
     * result in multiple OS calls if period is greater than the maximum sleep
     * duration supported by the operating system.
     *
     * Params:
     *  val = The minimum duration the calling thread should be suspended.
     *
     * In:
     *  period must be non-negative.
     *
     * Example:
     * ------------------------------------------------------------------------
     *
     * Thread.sleep( dur!("msecs")( 50 ) );  // sleep for 50 milliseconds
     * Thread.sleep( dur!("seconds")( 5 ) ); // sleep for 5 seconds
     *
     * ------------------------------------------------------------------------
     */
    static void sleep( Duration val )
    in
    {
        assert( !val.isNegative );
    }
    body
    {
        version( Windows )
        {
            auto maxSleepMillis = dur!("msecs")( uint.max - 1 );

            // avoid a non-zero time to be round down to 0
            if( val > dur!"msecs"( 0 ) && val < dur!"msecs"( 1 ) )
                val = dur!"msecs"( 1 );

            // NOTE: In instances where all other threads in the process have a
            //       lower priority than the current thread, the current thread
            //       will not yield with a sleep time of zero.  However, unlike
            //       yield(), the user is not asking for a yield to occur but
            //       only for execution to suspend for the requested interval.
            //       Therefore, expected performance may not be met if a yield
            //       is forced upon the user.
            while( val > maxSleepMillis )
            {
                Sleep( cast(uint)
                       maxSleepMillis.total!"msecs" );
                val -= maxSleepMillis;
            }
            Sleep( cast(uint) val.total!"msecs" );
        }
        else version( Posix )
        {
            timespec tin  = void;
            timespec tout = void;

            if( val.total!"seconds" > tin.tv_sec.max )
            {
                tin.tv_sec  = tin.tv_sec.max;
                tin.tv_nsec = cast(typeof(tin.tv_nsec)) val.fracSec.nsecs;
            }
            else
            {
                tin.tv_sec  = cast(typeof(tin.tv_sec)) val.total!"seconds";
                tin.tv_nsec = cast(typeof(tin.tv_nsec)) val.fracSec.nsecs;
            }
            while( true )
            {
                if( !nanosleep( &tin, &tout ) )
                    return;
                if( errno != EINTR )
                    throw new ThreadException( "Unable to sleep for the specified duration" );
                tin = tout;
            }
        }
    }


    /**
     * Forces a context switch to occur away from the calling thread.
     */
    static void yield()
    {
        version( Windows )
            SwitchToThread();
        else version( Posix )
            sched_yield();
    }


    ///////////////////////////////////////////////////////////////////////////
    // Thread Accessors
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Provides a reference to the calling thread.
     *
     * Returns:
     *  The thread object representing the calling thread.  The result of
     *  deleting this object is undefined.  If the current thread is not
     *  attached to the runtime, a null reference is returned.
     */
    static Thread getThis()
    {
        // NOTE: This function may not be called until thread_init has
        //       completed.  See thread_suspendAll for more information
        //       on why this might occur.
        return sm_this;
    }


    /**
     * Provides a list of all threads currently being tracked by the system.
     *
     * Returns:
     *  An array containing references to all threads currently being
     *  tracked by the system.  The result of deleting any contained
     *  objects is undefined.
     */
    static Thread[] getAll()
    {
        synchronized( slock )
        {
            size_t   pos = 0;
            Thread[] buf = new Thread[sm_tlen];

            foreach( Thread t; Thread )
            {
                buf[pos++] = t;
            }
            return buf;
        }
    }


    /**
     * Operates on all threads currently being tracked by the system.  The
     * result of deleting any Thread object is undefined.
     *
     * Params:
     *  dg = The supplied code as a delegate.
     *
     * Returns:
     *  Zero if all elemented are visited, nonzero if not.
     */
    static int opApply( scope int delegate( ref Thread ) dg )
    {
        synchronized( slock )
        {
            int ret = 0;

            for( Thread t = sm_tbeg; t; t = t.next )
            {
                ret = dg( t );
                if( ret )
                    break;
            }
            return ret;
        }
    }


    ///////////////////////////////////////////////////////////////////////////
    // Static Initalizer
    ///////////////////////////////////////////////////////////////////////////


    /**
     * This initializer is used to set thread constants.  All functional
     * initialization occurs within thread_init().
     */
    shared static this()
    {
        version( Windows )
        {
            PRIORITY_MIN = THREAD_PRIORITY_IDLE;
            PRIORITY_DEFAULT = THREAD_PRIORITY_NORMAL;
            PRIORITY_MAX = THREAD_PRIORITY_TIME_CRITICAL;
        }
        else version( Posix )
        {
            int         policy;
            sched_param param;
            pthread_t   self = pthread_self();

            int status = pthread_getschedparam( self, &policy, &param );
            assert( status == 0 );

            PRIORITY_MIN = sched_get_priority_min( policy );
            assert( PRIORITY_MIN != -1 );

            PRIORITY_DEFAULT = param.sched_priority;

            PRIORITY_MAX = sched_get_priority_max( policy );
            assert( PRIORITY_MAX != -1 );
        }
    }


    ///////////////////////////////////////////////////////////////////////////
    // Stuff That Should Go Away
    ///////////////////////////////////////////////////////////////////////////


private:
    //
    // Initializes a thread object which has no associated executable function.
    // This is used for the main thread initialized in thread_init().
    //
    this()
    {
        m_call = Call.NO;
        m_curr = &m_main;

        version (GNU)
        {
            auto pstart = cast(void*) &_tlsstart;
            auto pend   = cast(void*) &_tlsend;
            m_tls = pstart[0 .. pend - pstart];
        }
    }


    //
    // Thread entry point.  Invokes the function or delegate passed on
    // construction (if any).
    //
    final void run()
    {
        switch( m_call )
        {
        case Call.FN:
            m_fn();
            break;
        case Call.DG:
            m_dg();
            break;
        default:
            break;
        }
    }


private:
    //
    // The type of routine passed on thread construction.
    //
    enum Call
    {
        NO,
        FN,
        DG
    }


    //
    // Standard types
    //
    version( Windows )
    {
        alias uint TLSKey;
        alias uint ThreadAddr;
    }
    else version( Posix )
    {
        alias pthread_key_t TLSKey;
        alias pthread_t     ThreadAddr;
    }


    //
    // Local storage
    //
    static Thread       sm_this;


    //
    // Main process thread
    //
    __gshared Thread    sm_main;


    //
    // Standard thread data
    //
    version( Windows )
    {
        HANDLE          m_hndl;
    }
    else version( OSX )
    {
        mach_port_t     m_tmach;
    }
    ThreadAddr          m_addr;
    Call                m_call;
    string              m_name;
    union
    {
        void function() m_fn;
        void delegate() m_dg;
    }
    size_t              m_sz;
    version( Posix )
    {
        bool            m_isRunning;
    }
    bool                m_isDaemon;
    bool                m_isInCriticalRegion;
    Throwable           m_unhandled;


private:
    ///////////////////////////////////////////////////////////////////////////
    // Storage of Active Thread
    ///////////////////////////////////////////////////////////////////////////


    //
    // Sets a thread-local reference to the current thread object.
    //
    static void setThis( Thread t )
    {
        sm_this = t;
    }


private:
    ///////////////////////////////////////////////////////////////////////////
    // Thread Context and GC Scanning Support
    ///////////////////////////////////////////////////////////////////////////


    final void pushContext( Context* c )
    in
    {
        assert( !c.within );
    }
    body
    {
        c.within = m_curr;
        m_curr = c;
    }


    final void popContext()
    in
    {
        assert( m_curr && m_curr.within );
    }
    body
    {
        Context* c = m_curr;
        m_curr = c.within;
        c.within = null;
    }


    final Context* topContext()
    in
    {
        assert( m_curr );
    }
    body
    {
        return m_curr;
    }


    static struct Context
    {
        void*           bstack,
                        tstack;
        Context*        within;
        Context*        next,
                        prev;
    }


    Context             m_main;
    Context*            m_curr;
    bool                m_lock;
    version (GNU)
    {
        void[]          m_tls;  // spans implicit thread local storage
    }
    rt.tlsgc.Data*      m_tlsgcdata;

    version( Windows )
    {
      version( X86 )
      {
        uint[8]         m_reg; // edi,esi,ebp,esp,ebx,edx,ecx,eax
      }
      else version( X86_64 )
      {
        ulong[16]       m_reg; // rdi,rsi,rbp,rsp,rbx,rdx,rcx,rax
                               // r8,r9,r10,r11,r12,r13,r14,r15
      }
      else
      {
        static assert(false, "Architecture not supported." );
      }
    }
    else version( OSX )
    {
      version( X86 )
      {
        uint[8]         m_reg; // edi,esi,ebp,esp,ebx,edx,ecx,eax
      }
      else version( X86_64 )
      {
        ulong[16]       m_reg; // rdi,rsi,rbp,rsp,rbx,rdx,rcx,rax
                               // r8,r9,r10,r11,r12,r13,r14,r15
      }
      else
      {
        static assert(false, "Architecture not supported." );
      }
    }


private:
    ///////////////////////////////////////////////////////////////////////////
    // GC Scanning Support
    ///////////////////////////////////////////////////////////////////////////


    // NOTE: The GC scanning process works like so:
    //
    //          1. Suspend all threads.
    //          2. Scan the stacks of all suspended threads for roots.
    //          3. Resume all threads.
    //
    //       Step 1 and 3 require a list of all threads in the system, while
    //       step 2 requires a list of all thread stacks (each represented by
    //       a Context struct).  Traditionally, there was one stack per thread
    //       and the Context structs were not necessary.  However, Fibers have
    //       changed things so that each thread has its own 'main' stack plus
    //       an arbitrary number of nested stacks (normally referenced via
    //       m_curr).  Also, there may be 'free-floating' stacks in the system,
    //       which are Fibers that are not currently executing on any specific
    //       thread but are still being processed and still contain valid
    //       roots.
    //
    //       To support all of this, the Context struct has been created to
    //       represent a stack range, and a global list of Context structs has
    //       been added to enable scanning of these stack ranges.  The lifetime
    //       (and presence in the Context list) of a thread's 'main' stack will
    //       be equivalent to the thread's lifetime.  So the Ccontext will be
    //       added to the list on thread entry, and removed from the list on
    //       thread exit (which is essentially the same as the presence of a
    //       Thread object in its own global list).  The lifetime of a Fiber's
    //       context, however, will be tied to the lifetime of the Fiber object
    //       itself, and Fibers are expected to add/remove their Context struct
    //       on construction/deletion.


    //
    // All use of the global lists should synchronize on this lock.
    //
    @property static Mutex slock()
    {
        return cast(Mutex)_locks[0].ptr;
    }

    @property static Mutex criticalRegionLock()
    {
        return cast(Mutex)_locks[1].ptr;
    }

    __gshared byte[__traits(classInstanceSize, Mutex)][2] _locks;

    static void initLocks()
    {
        foreach (ref lock; _locks)
        {
            lock[] = Mutex.classinfo.init[];
            (cast(Mutex)lock.ptr).__ctor();
        }
    }

    static void termLocks()
    {
        foreach (ref lock; _locks)
            (cast(Mutex)lock.ptr).__dtor();
    }

    __gshared Context*  sm_cbeg;
    __gshared size_t    sm_clen;

    __gshared Thread    sm_tbeg;
    __gshared size_t    sm_tlen;

    //
    // Used for ordering threads in the global thread list.
    //
    Thread              prev;
    Thread              next;


    ///////////////////////////////////////////////////////////////////////////
    // Global Context List Operations
    ///////////////////////////////////////////////////////////////////////////


    //
    // Add a context to the global context list.
    //
    static void add( Context* c )
    in
    {
        assert( c );
        assert( !c.next && !c.prev );
    }
    body
    {
        // NOTE: This loop is necessary to avoid a race between newly created
        //       threads and the GC.  If a collection starts between the time
        //       Thread.start is called and the new thread calls Thread.add,
        //       the thread will have its stack scanned without first having
        //       been properly suspended.  Testing has shown this to sometimes
        //       cause a deadlock.

        while( true )
        {
            synchronized( slock )
            {
                if( !suspendDepth )
                {
                    if( sm_cbeg )
                    {
                        c.next = sm_cbeg;
                        sm_cbeg.prev = c;
                    }
                    sm_cbeg = c;
                    ++sm_clen;
                   return;
                }
            }
            yield();
        }
    }


    //
    // Remove a context from the global context list.
    //
    static void remove( Context* c )
    in
    {
        assert( c );
        assert( c.next || c.prev );
    }
    body
    {
        synchronized( slock )
        {
            if( c.prev )
                c.prev.next = c.next;
            if( c.next )
                c.next.prev = c.prev;
            if( sm_cbeg == c )
                sm_cbeg = c.next;
            --sm_clen;
        }
        // NOTE: Don't null out c.next or c.prev because opApply currently
        //       follows c.next after removing a node.  This could be easily
        //       addressed by simply returning the next node from this
        //       function, however, a context should never be re-added to the
        //       list anyway and having next and prev be non-null is a good way
        //       to ensure that.
    }


    ///////////////////////////////////////////////////////////////////////////
    // Global Thread List Operations
    ///////////////////////////////////////////////////////////////////////////


    //
    // Add a thread to the global thread list.
    //
    static void add( Thread t )
    in
    {
        assert( t );
        assert( !t.next && !t.prev );
        assert( t.isRunning );
    }
    body
    {
        // NOTE: This loop is necessary to avoid a race between newly created
        //       threads and the GC.  If a collection starts between the time
        //       Thread.start is called and the new thread calls Thread.add,
        //       the thread could manipulate global state while the collection
        //       is running, and by being added to the thread list it could be
        //       resumed by the GC when it was never suspended, which would
        //       result in an exception thrown by the GC code.
        //
        //       An alternative would be to have Thread.start call Thread.add
        //       for the new thread, but this may introduce its own problems,
        //       since the thread object isn't entirely ready to be operated
        //       on by the GC.  This could be fixed by tracking thread startup
        //       status, but it's far easier to simply have Thread.add wait
        //       for any running collection to stop before altering the thread
        //       list.
        //
        //       After further testing, having add wait for a collect to end
        //       proved to have its own problems (explained in Thread.start),
        //       so add(Thread) is now being done in Thread.start.  This
        //       reintroduced the deadlock issue mentioned in bugzilla 4890,
        //       which appears to have been solved by doing this same wait
        //       procedure in add(Context).  These comments will remain in
        //       case other issues surface that require the startup state
        //       tracking described above.

        while( true )
        {
            synchronized( slock )
            {
                if( !suspendDepth )
                {
                    if( sm_tbeg )
                    {
                        t.next = sm_tbeg;
                        sm_tbeg.prev = t;
                    }
                    sm_tbeg = t;
                    ++sm_tlen;
                    return;
                }
            }
            yield();
        }
    }


    //
    // Remove a thread from the global thread list.
    //
    static void remove( Thread t )
    in
    {
        assert( t );
        assert( t.next || t.prev );
    }
    body
    {
        synchronized( slock )
        {
            // NOTE: When a thread is removed from the global thread list its
            //       main context is invalid and should be removed as well.
            //       It is possible that t.m_curr could reference more
            //       than just the main context if the thread exited abnormally
            //       (if it was terminated), but we must assume that the user
            //       retains a reference to them and that they may be re-used
            //       elsewhere.  Therefore, it is the responsibility of any
            //       object that creates contexts to clean them up properly
            //       when it is done with them.
            remove( &t.m_main );

            if( t.prev )
                t.prev.next = t.next;
            if( t.next )
                t.next.prev = t.prev;
            if( sm_tbeg == t )
                sm_tbeg = t.next;
            --sm_tlen;
        }
        // NOTE: Don't null out t.next or t.prev because opApply currently
        //       follows t.next after removing a node.  This could be easily
        //       addressed by simply returning the next node from this
        //       function, however, a thread should never be re-added to the
        //       list anyway and having next and prev be non-null is a good way
        //       to ensure that.
    }
}

// These must be kept in sync with core/thread.di
version (GNU)
{
  version (D_LP64)
  {
    version (Windows)
        static assert(__traits(classInstanceSize, Thread) == 312);
    else version (OSX)
        static assert(__traits(classInstanceSize, Thread) == 320);
    else version (Solaris)
        static assert(__traits(classInstanceSize, Thread) == 176);
    else version (Posix)
        static assert(__traits(classInstanceSize, Thread) == 184);
    else
        static assert(0, "Platform not supported.");
  }
  else
  {
    static assert((void*).sizeof == 4); // 32-bit

    version (Windows)
        static assert(__traits(classInstanceSize, Thread) == 128);
    else version (OSX)
        static assert(__traits(classInstanceSize, Thread) == 128);
    else version (Posix)
        static assert(__traits(classInstanceSize, Thread) ==  92);
    else
        static assert(0, "Platform not supported.");

  }
}
else
version (D_LP64)
{
    version (Windows)
        static assert(__traits(classInstanceSize, Thread) == 296);
    else version (OSX)
        static assert(__traits(classInstanceSize, Thread) == 304);
    else version (Solaris)
        static assert(__traits(classInstanceSize, Thread) == 160);
    else version (Posix)
        static assert(__traits(classInstanceSize, Thread) == 168);
    else
            static assert(0, "Platform not supported.");
}
else
{
    static assert((void*).sizeof == 4); // 32-bit

    version (Windows)
        static assert(__traits(classInstanceSize, Thread) == 120);
    else version (OSX)
        static assert(__traits(classInstanceSize, Thread) == 120);
    else version (Posix)
        static assert(__traits(classInstanceSize, Thread) ==  84);
    else
        static assert(0, "Platform not supported.");
}


unittest
{
    int x = 0;

    auto t = new Thread(
    {
        x++;
    });
    t.start(); t.join();
    assert( x == 1 );
}


unittest
{
    enum MSG = "Test message.";
    string caughtMsg;

    try
    {
        auto t = new Thread(
        {
            throw new Exception( MSG );
        });
        t.start(); t.join();
        assert( false, "Expected rethrown exception." );
    }
    catch( Throwable t )
    {
        assert( t.msg == MSG );
    }
}


///////////////////////////////////////////////////////////////////////////////
// GC Support Routines
///////////////////////////////////////////////////////////////////////////////


/**
 * Initializes the thread module.  This function must be called by the
 * garbage collector on startup and before any other thread routines
 * are called.
 */
extern (C) void thread_init()
{
    // NOTE: If thread_init itself performs any allocations then the thread
    //       routines reserved for garbage collector use may be called while
    //       thread_init is being processed.  However, since no memory should
    //       exist to be scanned at this point, it is sufficient for these
    //       functions to detect the condition and return immediately.

    Thread.initLocks();

    version( OSX )
    {
    }
    else version( Posix )
    {
        int         status;
        sigaction_t sigusr1 = void;
        sigaction_t sigusr2 = void;

        // This is a quick way to zero-initialize the structs without using
        // memset or creating a link dependency on their static initializer.
        (cast(byte*) &sigusr1)[0 .. sigaction_t.sizeof] = 0;
        (cast(byte*) &sigusr2)[0 .. sigaction_t.sizeof] = 0;

        // NOTE: SA_RESTART indicates that system calls should restart if they
        //       are interrupted by a signal, but this is not available on all
        //       Posix systems, even those that support multithreading.
        static if( __traits( compiles, SA_RESTART ) )
            sigusr1.sa_flags = SA_RESTART;
        else
            sigusr1.sa_flags   = 0;
        sigusr1.sa_handler = &thread_suspendHandler;
        // NOTE: We want to ignore all signals while in this handler, so fill
        //       sa_mask to indicate this.
        status = sigfillset( &sigusr1.sa_mask );
        assert( status == 0 );

        // NOTE: Since SIGUSR2 should only be issued for threads within the
        //       suspend handler, we don't want this signal to trigger a
        //       restart.
        sigusr2.sa_flags   = 0;
        sigusr2.sa_handler = &thread_resumeHandler;
        // NOTE: We want to ignore all signals while in this handler, so fill
        //       sa_mask to indicate this.
        status = sigfillset( &sigusr2.sa_mask );
        assert( status == 0 );

        status = sigaction( SIGUSR1, &sigusr1, null );
        assert( status == 0 );

        status = sigaction( SIGUSR2, &sigusr2, null );
        assert( status == 0 );

        status = sem_init( &suspendCount, 0, 0 );
        assert( status == 0 );
    }
    Thread.sm_main = thread_attachThis();
}


/**
 * Terminates the thread module. No other thread routine may be called
 * afterwards.
 */
extern (C) void thread_term()
{
    Thread.termLocks();
}


/**
 *
 */
extern (C) bool thread_isMainThread()
{
    return Thread.getThis() is Thread.sm_main;
}


/**
 * Registers the calling thread for use with the D Runtime.  If this routine
 * is called for a thread which is already registered, no action is performed.
 */
extern (C) Thread thread_attachThis()
{
    gc_disable(); scope(exit) gc_enable();

    if (auto t = Thread.getThis())
        return t;

    Thread          thisThread  = new Thread();
    Thread.Context* thisContext = &thisThread.m_main;
    assert( thisContext == thisThread.m_curr );

    version( Windows )
    {
        thisThread.m_addr  = GetCurrentThreadId();
        thisThread.m_hndl  = GetCurrentThreadHandle();
        thisContext.bstack = getStackBottom();
        thisContext.tstack = thisContext.bstack;
    }
    else version( Posix )
    {
        thisThread.m_addr  = pthread_self();
        thisContext.bstack = getStackBottom();
        thisContext.tstack = thisContext.bstack;

        thisThread.m_isRunning = true;
    }
    thisThread.m_isDaemon = true;
    thisThread.m_tlsgcdata = rt.tlsgc.init();
    Thread.setThis( thisThread );

    version( OSX )
    {
        thisThread.m_tmach = pthread_mach_thread_np( thisThread.m_addr );
        assert( thisThread.m_tmach != thisThread.m_tmach.init );
    }

    version (GNU)
    {
        auto pstart = cast(void*) &_tlsstart;
        auto pend   = cast(void*) &_tlsend;
        thisThread.m_tls = pstart[0 .. pend - pstart];
    }

    Thread.add( thisThread );
    Thread.add( thisContext );
    if( Thread.sm_main !is null )
        multiThreadedFlag = true;
    return thisThread;
}


version( Windows )
{
    // NOTE: These calls are not safe on Posix systems that use signals to
    //       perform garbage collection.  The suspendHandler uses getThis()
    //       to get the thread handle so getThis() must be a simple call.
    //       Mutexes can't safely be acquired inside signal handlers, and
    //       even if they could, the mutex needed (Thread.slock) is held by
    //       thread_suspendAll().  So in short, these routines will remain
    //       Windows-specific.  If they are truly needed elsewhere, the
    //       suspendHandler will need a way to call a version of getThis()
    //       that only does the TLS lookup without the fancy fallback stuff.

    /// ditto
    extern (C) Thread thread_attachByAddr( Thread.ThreadAddr addr )
    {
        return thread_attachByAddrB( addr, getThreadStackBottom( addr ) );
    }


    /// ditto
    extern (C) Thread thread_attachByAddrB( Thread.ThreadAddr addr, void* bstack )
    {
        gc_disable(); scope(exit) gc_enable();

        if (auto t = thread_findByAddr(addr))
            return t;

        Thread          thisThread  = new Thread();
        Thread.Context* thisContext = &thisThread.m_main;
        assert( thisContext == thisThread.m_curr );

        thisThread.m_addr  = addr;
        thisContext.bstack = bstack;
        thisContext.tstack = thisContext.bstack;

        thisThread.m_isDaemon = true;

        if( addr == GetCurrentThreadId() )
        {
            thisThread.m_hndl = GetCurrentThreadHandle();
            thisThread.m_tlsgcdata = rt.tlsgc.init();
            version (GNU)
            {
                auto pstart = cast(void*) &_tlsstart;
                auto pend   = cast(void*) &_tlsend;
                thisThread.m_tls = pstart[0 .. pend - pstart];
            }
            Thread.setThis( thisThread );
        }
        else
        {
            thisThread.m_hndl = OpenThreadHandle( addr );
            impersonate_thread(addr,
            {
                thisThread.m_tlsgcdata = rt.tlsgc.init();
                version (GNU)
                {
                    auto pstart = cast(void*) &_tlsstart;
                    auto pend   = cast(void*) &_tlsend;
                    auto pos    = GetTlsDataAddress( thisThread.m_hndl );
                    if( pos ) // on x64, threads without TLS happen to exist
                        thisThread.m_tls = pos[0 .. pend - pstart];
                    else
                        thisThread.m_tls = [];
                }
                Thread.setThis( thisThread );
            });
        }

        Thread.add( thisThread );
        Thread.add( thisContext );
        if( Thread.sm_main !is null )
            multiThreadedFlag = true;
        return thisThread;
    }
}


/**
 * Deregisters the calling thread from use with the runtime.  If this routine
 * is called for a thread which is not registered, the result is undefined.
 */
extern (C) void thread_detachThis()
{
    if (auto t = Thread.getThis())
        Thread.remove(t);
}


/// ditto
extern (C) void thread_detachByAddr( Thread.ThreadAddr addr )
{
    if( auto t = thread_findByAddr( addr ) )
        Thread.remove( t );
}


/**
 * Search the list of all threads for a thread with the given thread identifier.
 *
 * Params:
 *  addr = The thread identifier to search for.
 * Returns:
 *  The thread object associated with the thread identifier, null if not found.
 */
static Thread thread_findByAddr( Thread.ThreadAddr addr )
{
    synchronized( Thread.slock )
    {
        foreach( t; Thread )
        {
                if( t.m_addr == addr )
                    return t;
        }
    }
    return null;
}


/**
 * Sets the current thread to a specific reference. Only to be used
 * when dealing with externally-created threads (in e.g. C code).
 * The primary use of this function is when Thread.getThis() must
 * return a sensible value in, for example, TLS destructors. In
 * other words, don't touch this unless you know what you're doing.
 *
 * Params:
 *  t = A reference to the current thread. May be null.
 */
extern (C) void thread_setThis(Thread t)
{
    Thread.setThis(t);
}


/**
 * Joins all non-daemon threads that are currently running.  This is done by
 * performing successive scans through the thread list until a scan consists
 * of only daemon threads.
 */
extern (C) void thread_joinAll()
{

    while( true )
    {
        Thread nonDaemon = null;

        foreach( t; Thread )
        {
            if( !t.isRunning )
            {
                Thread.remove( t );
                continue;
            }
            if( !t.isDaemon )
            {
                nonDaemon = t;
                break;
            }
        }
        if( nonDaemon is null )
            return;
        nonDaemon.join();
    }
}


/**
 * Performs intermediate shutdown of the thread module.
 */
shared static ~this()
{
    // NOTE: The functionality related to garbage collection must be minimally
    //       operable after this dtor completes.  Therefore, only minimal
    //       cleanup may occur.

    for( Thread t = Thread.sm_tbeg; t; t = t.next )
    {
        if( !t.isRunning )
            Thread.remove( t );
    }
}


// Used for needLock below.
private __gshared bool multiThreadedFlag = false;

version (PPC64) version = ExternStackShell;

version (ExternStackShell)
{
    extern(D) public void callWithStackShell(scope void delegate(void* sp) fn);
}
else
{
    // Calls the given delegate, passing the current thread's stack pointer to it.
    private void callWithStackShell(scope void delegate(void* sp) fn)
    in
    {
        assert(fn);
    }
    body
    {
        // The purpose of the 'shell' is to ensure all the registers get
        // put on the stack so they'll be scanned. We only need to push
        // the callee-save registers.
        void *sp = void;

        version (GNU)
        {
            __builtin_unwind_init();
            sp = &sp;
        }
        else version (AsmX86_Posix)
        {
            size_t[3] regs = void;
            asm
            {
                mov [regs + 0 * 4], EBX;
                mov [regs + 1 * 4], ESI;
                mov [regs + 2 * 4], EDI;

                mov sp[EBP], ESP;
            }
        }
        else version (AsmX86_Windows)
        {
            size_t[3] regs = void;
            asm
            {
                mov [regs + 0 * 4], EBX;
                mov [regs + 1 * 4], ESI;
                mov [regs + 2 * 4], EDI;

                mov sp[EBP], ESP;
            }
        }
        else version (AsmX86_64_Posix)
        {
            size_t[5] regs = void;
            asm
            {
                mov [regs + 0 * 8], RBX;
                mov [regs + 1 * 8], R12;
                mov [regs + 2 * 8], R13;
                mov [regs + 3 * 8], R14;
                mov [regs + 4 * 8], R15;

                mov sp[RBP], RSP;
            }
        }
        else version (AsmX86_64_Windows)
        {
            size_t[7] regs = void;
            asm
            {
                mov [regs + 0 * 8], RBX;
                mov [regs + 1 * 8], RSI;
                mov [regs + 2 * 8], RDI;
                mov [regs + 3 * 8], R12;
                mov [regs + 4 * 8], R13;
                mov [regs + 5 * 8], R14;
                mov [regs + 6 * 8], R15;

                mov sp[RBP], RSP;
            }
        }
        else
        {
            static assert(false, "Architecture not supported.");
        }

        fn(sp);
    }
}

// Used for suspendAll/resumeAll below.
private __gshared uint suspendDepth = 0;

/**
 * Suspend the specified thread and load stack and register information for
 * use by thread_scanAll.  If the supplied thread is the calling thread,
 * stack and register information will be loaded but the thread will not
 * be suspended.  If the suspend operation fails and the thread is not
 * running then it will be removed from the global thread list, otherwise
 * an exception will be thrown.
 *
 * Params:
 *  t = The thread to suspend.
 *
 * Throws:
 *  ThreadException if the suspend operation fails for a running thread.
 */
private void suspend( Thread t )
{
    version( Windows )
    {
        if( t.m_addr != GetCurrentThreadId() && SuspendThread( t.m_hndl ) == 0xFFFFFFFF )
        {
            if( !t.isRunning )
            {
                Thread.remove( t );
                return;
            }
            throw new ThreadException( "Unable to suspend thread" );
        }

        CONTEXT context = void;
        context.ContextFlags = CONTEXT_INTEGER | CONTEXT_CONTROL;

        if( !GetThreadContext( t.m_hndl, &context ) )
            throw new ThreadException( "Unable to load thread context" );
        version( X86 )
        {
            if( !t.m_lock )
                t.m_curr.tstack = cast(void*) context.Esp;
            // eax,ebx,ecx,edx,edi,esi,ebp,esp
            t.m_reg[0] = context.Eax;
            t.m_reg[1] = context.Ebx;
            t.m_reg[2] = context.Ecx;
            t.m_reg[3] = context.Edx;
            t.m_reg[4] = context.Edi;
            t.m_reg[5] = context.Esi;
            t.m_reg[6] = context.Ebp;
            t.m_reg[7] = context.Esp;
        }
        else version( X86_64 )
        {
            if( !t.m_lock )
                t.m_curr.tstack = cast(void*) context.Rsp;
            // rax,rbx,rcx,rdx,rdi,rsi,rbp,rsp
            t.m_reg[0] = context.Rax;
            t.m_reg[1] = context.Rbx;
            t.m_reg[2] = context.Rcx;
            t.m_reg[3] = context.Rdx;
            t.m_reg[4] = context.Rdi;
            t.m_reg[5] = context.Rsi;
            t.m_reg[6] = context.Rbp;
            t.m_reg[7] = context.Rsp;
            // r8,r9,r10,r11,r12,r13,r14,r15
            t.m_reg[8]  = context.R8;
            t.m_reg[9]  = context.R9;
            t.m_reg[10] = context.R10;
            t.m_reg[11] = context.R11;
            t.m_reg[12] = context.R12;
            t.m_reg[13] = context.R13;
            t.m_reg[14] = context.R14;
            t.m_reg[15] = context.R15;
        }
        else
        {
            static assert(false, "Architecture not supported." );
        }
    }
    else version( OSX )
    {
        if( t.m_addr != pthread_self() && thread_suspend( t.m_tmach ) != KERN_SUCCESS )
        {
            if( !t.isRunning )
            {
                Thread.remove( t );
                return;
            }
            throw new ThreadException( "Unable to suspend thread" );
        }

        version( X86 )
        {
            x86_thread_state32_t    state = void;
            mach_msg_type_number_t  count = x86_THREAD_STATE32_COUNT;

            if( thread_get_state( t.m_tmach, x86_THREAD_STATE32, &state, &count ) != KERN_SUCCESS )
                throw new ThreadException( "Unable to load thread state" );
            if( !t.m_lock )
                t.m_curr.tstack = cast(void*) state.esp;
            // eax,ebx,ecx,edx,edi,esi,ebp,esp
            t.m_reg[0] = state.eax;
            t.m_reg[1] = state.ebx;
            t.m_reg[2] = state.ecx;
            t.m_reg[3] = state.edx;
            t.m_reg[4] = state.edi;
            t.m_reg[5] = state.esi;
            t.m_reg[6] = state.ebp;
            t.m_reg[7] = state.esp;
        }
        else version( X86_64 )
        {
            x86_thread_state64_t    state = void;
            mach_msg_type_number_t  count = x86_THREAD_STATE64_COUNT;

            if( thread_get_state( t.m_tmach, x86_THREAD_STATE64, &state, &count ) != KERN_SUCCESS )
                throw new ThreadException( "Unable to load thread state" );
            if( !t.m_lock )
                t.m_curr.tstack = cast(void*) state.rsp;
            // rax,rbx,rcx,rdx,rdi,rsi,rbp,rsp
            t.m_reg[0] = state.rax;
            t.m_reg[1] = state.rbx;
            t.m_reg[2] = state.rcx;
            t.m_reg[3] = state.rdx;
            t.m_reg[4] = state.rdi;
            t.m_reg[5] = state.rsi;
            t.m_reg[6] = state.rbp;
            t.m_reg[7] = state.rsp;
            // r8,r9,r10,r11,r12,r13,r14,r15
            t.m_reg[8]  = state.r8;
            t.m_reg[9]  = state.r9;
            t.m_reg[10] = state.r10;
            t.m_reg[11] = state.r11;
            t.m_reg[12] = state.r12;
            t.m_reg[13] = state.r13;
            t.m_reg[14] = state.r14;
            t.m_reg[15] = state.r15;
        }
        else
        {
            static assert(false, "Architecture not supported." );
        }
    }
    else version( Posix )
    {
        if( t.m_addr != pthread_self() )
        {
            if( pthread_kill( t.m_addr, SIGUSR1 ) != 0 )
            {
                if( !t.isRunning )
                {
                    Thread.remove( t );
                    return;
                }
                throw new ThreadException( "Unable to suspend thread" );
            }
            while (sem_wait(&suspendCount) != 0)
            {
                if (errno != EINTR)
                    throw new ThreadException( "Unable to wait for semaphore" );
                errno = 0;
            }
        }
        else if( !t.m_lock )
        {
            t.m_curr.tstack = getStackTop();
        }
    }
}

/**
 * Suspend all threads but the calling thread for "stop the world" garbage
 * collection runs.  This function may be called multiple times, and must
 * be followed by a matching number of calls to thread_resumeAll before
 * processing is resumed.
 *
 * Throws:
 *  ThreadException if the suspend operation fails for a running thread.
 */
extern (C) void thread_suspendAll()
{
    // NOTE: We've got an odd chicken & egg problem here, because while the GC
    //       is required to call thread_init before calling any other thread
    //       routines, thread_init may allocate memory which could in turn
    //       trigger a collection.  Thus, thread_suspendAll, thread_scanAll,
    //       and thread_resumeAll must be callable before thread_init
    //       completes, with the assumption that no other GC memory has yet
    //       been allocated by the system, and thus there is no risk of losing
    //       data if the global thread list is empty.  The check of
    //       Thread.sm_tbeg below is done to ensure thread_init has completed,
    //       and therefore that calling Thread.getThis will not result in an
    //       error.  For the short time when Thread.sm_tbeg is null, there is
    //       no reason not to simply call the multithreaded code below, with
    //       the expectation that the foreach loop will never be entered.
    if( !multiThreadedFlag && Thread.sm_tbeg )
    {
        if( ++suspendDepth == 1 )
            suspend( Thread.getThis() );

        return;
    }

    Thread.slock.lock();
    {
        if( ++suspendDepth > 1 )
            return;

        // NOTE: I'd really prefer not to check isRunning within this loop but
        //       not doing so could be problematic if threads are terminated
        //       abnormally and a new thread is created with the same thread
        //       address before the next GC run.  This situation might cause
        //       the same thread to be suspended twice, which would likely
        //       cause the second suspend to fail, the garbage collection to
        //       abort, and Bad Things to occur.

        Thread.criticalRegionLock.lock();
        for (Thread t = Thread.sm_tbeg; t !is null; t = t.next)
        {
            Duration waittime = dur!"usecs"(10);
        Lagain:
            if (!t.isRunning)
            {
                Thread.remove(t);
            }
            else if (t.m_isInCriticalRegion)
            {
                Thread.criticalRegionLock.unlock();
                Thread.sleep(waittime);
                if (waittime < dur!"msecs"(10)) waittime *= 2;
                Thread.criticalRegionLock.lock();
                goto Lagain;
            }
            else
            {
                suspend(t);
            }
        }
        Thread.criticalRegionLock.unlock();
    }
}

/**
 * Resume the specified thread and unload stack and register information.
 * If the supplied thread is the calling thread, stack and register
 * information will be unloaded but the thread will not be resumed.  If
 * the resume operation fails and the thread is not running then it will
 * be removed from the global thread list, otherwise an exception will be
 * thrown.
 *
 * Params:
 *  t = The thread to resume.
 *
 * Throws:
 *  ThreadException if the resume fails for a running thread.
 */
private void resume( Thread t )
{
    version( Windows )
    {
        if( t.m_addr != GetCurrentThreadId() && ResumeThread( t.m_hndl ) == 0xFFFFFFFF )
        {
            if( !t.isRunning )
            {
                Thread.remove( t );
                return;
            }
            throw new ThreadException( "Unable to resume thread" );
        }

        if( !t.m_lock )
            t.m_curr.tstack = t.m_curr.bstack;
        t.m_reg[0 .. $] = 0;
    }
    else version( OSX )
    {
        if( t.m_addr != pthread_self() && thread_resume( t.m_tmach ) != KERN_SUCCESS )
        {
            if( !t.isRunning )
            {
                Thread.remove( t );
                return;
            }
            throw new ThreadException( "Unable to resume thread" );
        }

        if( !t.m_lock )
            t.m_curr.tstack = t.m_curr.bstack;
        t.m_reg[0 .. $] = 0;
    }
    else version( Posix )
    {
        if( t.m_addr != pthread_self() )
        {
            if( pthread_kill( t.m_addr, SIGUSR2 ) != 0 )
            {
                if( !t.isRunning )
                {
                    Thread.remove( t );
                    return;
                }
                throw new ThreadException( "Unable to resume thread" );
            }
        }
        else if( !t.m_lock )
        {
            t.m_curr.tstack = t.m_curr.bstack;
        }
    }
}

/**
 * Resume all threads but the calling thread for "stop the world" garbage
 * collection runs.  This function must be called once for each preceding
 * call to thread_suspendAll before the threads are actually resumed.
 *
 * In:
 *  This routine must be preceded by a call to thread_suspendAll.
 *
 * Throws:
 *  ThreadException if the resume operation fails for a running thread.
 */
extern (C) void thread_resumeAll()
in
{
    assert( suspendDepth > 0 );
}
body
{
    // NOTE: See thread_suspendAll for the logic behind this.
    if( !multiThreadedFlag && Thread.sm_tbeg )
    {
        if( --suspendDepth == 0 )
            resume( Thread.getThis() );
        return;
    }

    scope(exit) Thread.slock.unlock();
    {
        if( --suspendDepth > 0 )
            return;

        for( Thread t = Thread.sm_tbeg; t; t = t.next )
        {
            // NOTE: We do not need to care about critical regions at all
            //       here. thread_suspendAll takes care of everything.
            resume( t );
        }
    }
}

enum ScanType
{
    stack,
    tls,
}

alias void delegate(void*, void*) ScanAllThreadsFn;
alias void delegate(ScanType, void*, void*) ScanAllThreadsTypeFn;

extern (C) void thread_scanAllType( scope ScanAllThreadsTypeFn scan )
in
{
    assert( suspendDepth > 0 );
}
body
{
    callWithStackShell(sp => scanAllTypeImpl(scan, sp));
}


private void scanAllTypeImpl( scope ScanAllThreadsTypeFn scan, void* curStackTop )
{
    Thread  thisThread  = null;
    void*   oldStackTop = null;

    if( Thread.sm_tbeg )
    {
        thisThread  = Thread.getThis();
        if( !thisThread.m_lock )
        {
            oldStackTop = thisThread.m_curr.tstack;
            thisThread.m_curr.tstack = curStackTop;
        }
    }

    scope( exit )
    {
        if( Thread.sm_tbeg )
        {
            if( !thisThread.m_lock )
            {
                thisThread.m_curr.tstack = oldStackTop;
            }
        }
    }

    // NOTE: Synchronizing on Thread.slock is not needed because this
    //       function may only be called after all other threads have
    //       been suspended from within the same lock.
    for( Thread.Context* c = Thread.sm_cbeg; c; c = c.next )
    {
        version( StackGrowsDown )
        {
            // NOTE: We can't index past the bottom of the stack
            //       so don't do the "+1" for StackGrowsDown.
            if( c.tstack && c.tstack < c.bstack )
                scan( ScanType.stack, c.tstack, c.bstack );
        }
        else
        {
            if( c.bstack && c.bstack < c.tstack )
                scan( ScanType.stack, c.bstack, c.tstack + 1 );
        }
    }

    for( Thread t = Thread.sm_tbeg; t; t = t.next )
    {
        version( Windows )
        {
            // Ideally, we'd pass ScanType.regs or something like that, but this
            // would make portability annoying because it only makes sense on Windows.
            scan( ScanType.stack, t.m_reg.ptr, t.m_reg.ptr + t.m_reg.length );
        }
        version (GNU)
            scan( ScanType.tls, t.m_tls.ptr, t.m_tls.ptr + t.m_tls.length );

        if (t.m_tlsgcdata !is null)
            rt.tlsgc.scan(t.m_tlsgcdata, (p1, p2) => scan(ScanType.tls, p1, p2));
    }
}


extern (C) void thread_scanAll( scope ScanAllThreadsFn scan )
{
    thread_scanAllType((type, p1, p2) => scan(p1, p2));
}

extern (C) void thread_enterCriticalRegion()
in
{
    assert(Thread.getThis());
}
body
{
    synchronized (Thread.criticalRegionLock)
        Thread.getThis().m_isInCriticalRegion = true;
}

extern (C) void thread_exitCriticalRegion()
in
{
    assert(Thread.getThis());
}
body
{
    synchronized (Thread.criticalRegionLock)
        Thread.getThis().m_isInCriticalRegion = false;
}

extern (C) bool thread_inCriticalRegion()
in
{
    assert(Thread.getThis());
}
body
{
    synchronized (Thread.criticalRegionLock)
        return Thread.getThis().m_isInCriticalRegion;
}

unittest
{
    assert(!thread_inCriticalRegion());

    {
        thread_enterCriticalRegion();

        scope (exit)
            thread_exitCriticalRegion();

        assert(thread_inCriticalRegion());
    }

    assert(!thread_inCriticalRegion());
}

unittest
{
    // NOTE: This entire test is based on the assumption that no
    //       memory is allocated after the child thread is
    //       started. If an allocation happens, a collection could
    //       trigger, which would cause the synchronization below
    //       to cause a deadlock.
    // NOTE: DO NOT USE LOCKS IN CRITICAL REGIONS IN NORMAL CODE.

    import core.sync.semaphore;

    auto sema = new Semaphore(),
         semb = new Semaphore();

    auto thr = new Thread(
    {
        thread_enterCriticalRegion();
        assert(thread_inCriticalRegion());
        sema.notify();

        semb.wait();
        assert(thread_inCriticalRegion());

        thread_exitCriticalRegion();
        assert(!thread_inCriticalRegion());
        sema.notify();

        semb.wait();
        assert(!thread_inCriticalRegion());
    });

    thr.start();

    sema.wait();
    synchronized (Thread.criticalRegionLock)
        assert(thr.m_isInCriticalRegion);
    semb.notify();

    sema.wait();
    synchronized (Thread.criticalRegionLock)
        assert(!thr.m_isInCriticalRegion);
    semb.notify();

    thr.join();
}

unittest
{
    import core.sync.semaphore;

    shared bool inCriticalRegion;
    auto sem = new Semaphore();

    auto thr = new Thread(
    {
        thread_enterCriticalRegion();
        inCriticalRegion = true;
        sem.notify();
        Thread.sleep(dur!"msecs"(1));
        inCriticalRegion = false;
        thread_exitCriticalRegion();
    });
    thr.start();

    sem.wait();
    assert(inCriticalRegion);
    thread_suspendAll();
    assert(!inCriticalRegion);
    thread_resumeAll();
}

/**
 * This routine allows the runtime to process any special per-thread handling
 * for the GC.  This is needed for taking into account any memory that is
 * referenced by non-scanned pointers but is about to be freed.  That currently
 * means the array append cache.
 *
 * Params:
 *  hasMarks = The probe function. It should return true for pointers into marked memory blocks.
 *
 * In:
 *  This routine must be called just prior to resuming all threads.
 */
extern(C) void thread_processGCMarks(scope rt.tlsgc.IsMarkedDg dg)
{
    for( Thread t = Thread.sm_tbeg; t; t = t.next )
    {
        /* Can be null if collection was triggered between adding a
         * thread and calling rt.tlsgc.init.
         */
        if (t.m_tlsgcdata !is null)
            rt.tlsgc.processGCMarks(t.m_tlsgcdata, dg);
    }
}


extern (C)
{
    version (linux) int pthread_getattr_np(pthread_t thread, pthread_attr_t* attr);
    version (FreeBSD) int pthread_attr_get_np(pthread_t thread, pthread_attr_t* attr);
    version (Solaris) int thr_stksegment(stack_t* stk);
}


private void* getStackTop()
{
    version (D_InlineAsm_X86)
        asm { naked; mov EAX, ESP; ret; }
    else version (D_InlineAsm_X86_64)
        asm { naked; mov RAX, RSP; ret; }
    else version (GNU)
        return __builtin_frame_address(0);
    else
        static assert(false, "Architecture not supported.");
}


private void* getStackBottom()
{
    version (Windows)
    {
        version (D_InlineAsm_X86)
            asm { naked; mov EAX, FS:4; ret; }
        else version(D_InlineAsm_X86_64)
            asm
            {    naked;
                 mov RAX, 8;
                 mov RAX, GS:[RAX];
                 ret;
            }
        else
            static assert(false, "Architecture not supported.");
    }
    else version (OSX)
    {
        import core.sys.osx.pthread;
        return pthread_get_stackaddr_np(pthread_self());
    }
    else version (linux)
    {
        pthread_attr_t attr;
        void* addr; size_t size;

        pthread_getattr_np(pthread_self(), &attr);
        pthread_attr_getstack(&attr, &addr, &size);
        pthread_attr_destroy(&attr);
        return addr + size;
    }
    else version (FreeBSD)
    {
        pthread_attr_t attr;
        void* addr; size_t size;

        pthread_attr_init(&attr);
        pthread_attr_get_np(pthread_self(), &attr);
        pthread_attr_getstack(&attr, &addr, &size);
        pthread_attr_destroy(&attr);
        return addr + size;
    }
    else version (Solaris)
    {
        stack_t stk;

        thr_stksegment(&stk);
        return stk.ss_sp;
    }
    else
        static assert(false, "Platform not supported.");
}


extern (C) void* thread_stackTop()
in
{
    // Not strictly required, but it gives us more flexibility.
    assert(Thread.getThis());
}
body
{
    return getStackTop();
}


extern (C) void* thread_stackBottom()
in
{
    assert(Thread.getThis());
}
body
{
    return Thread.getThis().topContext().bstack;
}


///////////////////////////////////////////////////////////////////////////////
// Thread Group
///////////////////////////////////////////////////////////////////////////////


/**
 * This class is intended to simplify certain common programming techniques.
 */
class ThreadGroup
{
    /**
     * Creates and starts a new Thread object that executes fn and adds it to
     * the list of tracked threads.
     *
     * Params:
     *  fn = The thread function.
     *
     * Returns:
     *  A reference to the newly created thread.
     */
    final Thread create( void function() fn )
    {
        Thread t = new Thread( fn );

        t.start();
        synchronized( this )
        {
            m_all[t] = t;
        }
        return t;
    }


    /**
     * Creates and starts a new Thread object that executes dg and adds it to
     * the list of tracked threads.
     *
     * Params:
     *  dg = The thread function.
     *
     * Returns:
     *  A reference to the newly created thread.
     */
    final Thread create( void delegate() dg )
    {
        Thread t = new Thread( dg );

        t.start();
        synchronized( this )
        {
            m_all[t] = t;
        }
        return t;
    }


    /**
     * Add t to the list of tracked threads if it is not already being tracked.
     *
     * Params:
     *  t = The thread to add.
     *
     * In:
     *  t must not be null.
     */
    final void add( Thread t )
    in
    {
        assert( t );
    }
    body
    {
        synchronized( this )
        {
            m_all[t] = t;
        }
    }


    /**
     * Removes t from the list of tracked threads.  No operation will be
     * performed if t is not currently being tracked by this object.
     *
     * Params:
     *  t = The thread to remove.
     *
     * In:
     *  t must not be null.
     */
    final void remove( Thread t )
    in
    {
        assert( t );
    }
    body
    {
        synchronized( this )
        {
            m_all.remove( t );
        }
    }


    /**
     * Operates on all threads currently tracked by this object.
     */
    final int opApply( scope int delegate( ref Thread ) dg )
    {
        synchronized( this )
        {
            int ret = 0;

            // NOTE: This loop relies on the knowledge that m_all uses the
            //       Thread object for both the key and the mapped value.
            foreach( Thread t; m_all.keys )
            {
                ret = dg( t );
                if( ret )
                    break;
            }
            return ret;
        }
    }


    /**
     * Iteratively joins all tracked threads.  This function will block add,
     * remove, and opApply until it completes.
     *
     * Params:
     *  rethrow = Rethrow any unhandled exception which may have caused the
     *            current thread to terminate.
     *
     * Throws:
     *  Any exception not handled by the joined threads.
     */
    final void joinAll( bool rethrow = true )
    {
        synchronized( this )
        {
            // NOTE: This loop relies on the knowledge that m_all uses the
            //       Thread object for both the key and the mapped value.
            foreach( Thread t; m_all.keys )
            {
                t.join( rethrow );
            }
        }
    }


private:
    Thread[Thread]  m_all;
}

// These must be kept in sync with core/thread.di
version (D_LP64)
{
    static assert(__traits(classInstanceSize, ThreadGroup) == 24);
}
else
{
    static assert((void*).sizeof == 4); // 32-bit
    static assert(__traits(classInstanceSize, ThreadGroup) == 12);
}


///////////////////////////////////////////////////////////////////////////////
// Fiber Platform Detection and Memory Allocation
///////////////////////////////////////////////////////////////////////////////


private
{
    version( D_InlineAsm_X86 )
    {
        version( Windows )
            version = AsmX86_Windows;
        else version( Posix )
            version = AsmX86_Posix;

        version( OSX )
            version = AlignFiberStackTo16Byte;
    }
    else version( D_InlineAsm_X86_64 )
    {
        version( Windows )
        {
            version = AsmX86_64_Windows;
            version = AlignFiberStackTo16Byte;
        }
        else version( Posix )
        {
            version = AsmX86_64_Posix;
            version = AlignFiberStackTo16Byte;
        }
    }
    else version( PPC )
    {
        version( Posix )
        {
            version = AsmPPC_Posix;
            version = AsmExternal;
        }
    }
    else version( PPC64 )
    {
        version( Posix )
        {
            version = AlignFiberStackTo16Byte;
        }
    }
    else version( MIPS_O32 )
    {
        version( Posix )
        {
            version = AsmMIPS_O32_Posix;
            version = AsmExternal;
        }
    }


    version( Posix )
    {
        import core.sys.posix.unistd;   // for sysconf

        version( AsmX86_Windows )    {} else
        version( AsmX86_Posix )      {} else
        version( AsmX86_64_Windows ) {} else
        version( AsmX86_64_Posix )   {} else
        version( AsmExternal )       {} else
        {
            // NOTE: The ucontext implementation requires architecture specific
            //       data definitions to operate so testing for it must be done
            //       by checking for the existence of ucontext_t rather than by
            //       a version identifier.  Please note that this is considered
            //       an obsolescent feature according to the POSIX spec, so a
            //       custom solution is still preferred.
            import core.sys.posix.ucontext;
        }
    }

    __gshared const size_t PAGESIZE;
}


shared static this()
{
    static if( __traits( compiles, GetSystemInfo ) )
    {
        SYSTEM_INFO info;
        GetSystemInfo( &info );

        PAGESIZE = info.dwPageSize;
        assert( PAGESIZE < int.max );
    }
    else static if( __traits( compiles, sysconf ) &&
                    __traits( compiles, _SC_PAGESIZE ) )
    {
        PAGESIZE = cast(size_t) sysconf( _SC_PAGESIZE );
        assert( PAGESIZE < int.max );
    }
    else
    {
        version( PPC )
            PAGESIZE = 8192;
        else
            PAGESIZE = 4096;
    }
}


///////////////////////////////////////////////////////////////////////////////
// Fiber Entry Point and Context Switch
///////////////////////////////////////////////////////////////////////////////


private
{
    extern (C) void fiber_entryPoint()
    {
        Fiber   obj = Fiber.getThis();
        assert( obj );

        assert( Thread.getThis().m_curr is obj.m_ctxt );
        atomicStore!(MemoryOrder.raw)(*cast(shared)&Thread.getThis().m_lock, false);
        obj.m_ctxt.tstack = obj.m_ctxt.bstack;
        obj.m_state = Fiber.State.EXEC;

        try
        {
            obj.run();
        }
        catch( Throwable t )
        {
            obj.m_unhandled = t;
        }

        static if( __traits( compiles, ucontext_t ) )
          obj.m_ucur = &obj.m_utxt;

        obj.m_state = Fiber.State.TERM;
        obj.switchOut();
    }


  version( AsmExternal )
    extern (C) void fiber_switchContext( void** oldp, void* newp );
  else
    extern (C) void fiber_switchContext( void** oldp, void* newp )
    {
        // NOTE: The data pushed and popped in this routine must match the
        //       default stack created by Fiber.initStack or the initial
        //       switch into a new context will fail.

        version( AsmX86_Windows )
        {
            asm
            {
                naked;

                // save current stack state
                push EBP;
                mov  EBP, ESP;
                push EDI;
                push ESI;
                push EBX;
                push dword ptr FS:[0];
                push dword ptr FS:[4];
                push dword ptr FS:[8];
                push EAX;

                // store oldp again with more accurate address
                mov EAX, dword ptr 8[EBP];
                mov [EAX], ESP;
                // load newp to begin context switch
                mov ESP, dword ptr 12[EBP];

                // load saved state from new stack
                pop EAX;
                pop dword ptr FS:[8];
                pop dword ptr FS:[4];
                pop dword ptr FS:[0];
                pop EBX;
                pop ESI;
                pop EDI;
                pop EBP;

                // 'return' to complete switch
                pop ECX;
                jmp ECX;
            }
        }
        else version( AsmX86_64_Windows )
        {
            asm
            {
                naked;

                // save current stack state
                push RBP;
                mov  RBP, RSP;
                push RBX;
                push R12;
                push R13;
                push R14;
                push R15;
                xor  RCX,RCX;
                push qword ptr GS:[RCX];
                push qword ptr GS:8[RCX];
                push qword ptr GS:16[RCX];

                // store oldp
                mov [RDI], RSP;
                // load newp to begin context switch
                mov RSP, RSI;

                // load saved state from new stack
                pop qword ptr GS:16[RCX];
                pop qword ptr GS:8[RCX];
                pop qword ptr GS:[RCX];
                pop R15;
                pop R14;
                pop R13;
                pop R12;
                pop RBX;
                pop RBP;

                // 'return' to complete switch
                pop RCX;
                jmp RCX;
            }
        }
        else version( AsmX86_Posix )
        {
            asm
            {
                naked;

                // save current stack state
                push EBP;
                mov  EBP, ESP;
                push EDI;
                push ESI;
                push EBX;
                push EAX;

                // store oldp again with more accurate address
                mov EAX, dword ptr 8[EBP];
                mov [EAX], ESP;
                // load newp to begin context switch
                mov ESP, dword ptr 12[EBP];

                // load saved state from new stack
                pop EAX;
                pop EBX;
                pop ESI;
                pop EDI;
                pop EBP;

                // 'return' to complete switch
                pop ECX;
                jmp ECX;
            }
        }
        else version( AsmX86_64_Posix )
        {
            asm
            {
                naked;

                // save current stack state
                push RBP;
                mov  RBP, RSP;
                push RBX;
                push R12;
                push R13;
                push R14;
                push R15;

                // store oldp
                mov [RDI], RSP;
                // load newp to begin context switch
                mov RSP, RSI;

                // load saved state from new stack
                pop R15;
                pop R14;
                pop R13;
                pop R12;
                pop RBX;
                pop RBP;

                // 'return' to complete switch
                pop RCX;
                jmp RCX;
            }
        }
        else static if( __traits( compiles, ucontext_t ) )
        {
            Fiber   cfib = Fiber.getThis();
            void*   ucur = cfib.m_ucur;

            *oldp = &ucur;
            swapcontext( **(cast(ucontext_t***) oldp),
                          *(cast(ucontext_t**)  newp) );
        }
        else
            static assert(0, "Not implemented");
    }
}


///////////////////////////////////////////////////////////////////////////////
// Fiber
///////////////////////////////////////////////////////////////////////////////


/**
 * This class provides a cooperative concurrency mechanism integrated with the
 * threading and garbage collection functionality.  Calling a fiber may be
 * considered a blocking operation that returns when the fiber yields (via
 * Fiber.yield()).  Execution occurs within the context of the calling thread
 * so synchronization is not necessary to guarantee memory visibility so long
 * as the same thread calls the fiber each time.  Please note that there is no
 * requirement that a fiber be bound to one specific thread.  Rather, fibers
 * may be freely passed between threads so long as they are not currently
 * executing.  Like threads, a new fiber thread may be created using either
 * derivation or composition, as in the following example.
 *
 * Example:
 * ----------------------------------------------------------------------
 *
 * class DerivedFiber : Fiber
 * {
 *     this()
 *     {
 *         super( &run );
 *     }
 *
 * private :
 *     void run()
 *     {
 *         printf( "Derived fiber running.\n" );
 *     }
 * }
 *
 * void fiberFunc()
 * {
 *     printf( "Composed fiber running.\n" );
 *     Fiber.yield();
 *     printf( "Composed fiber running.\n" );
 * }
 *
 * // create instances of each type
 * Fiber derived = new DerivedFiber();
 * Fiber composed = new Fiber( &fiberFunc );
 *
 * // call both fibers once
 * derived.call();
 * composed.call();
 * printf( "Execution returned to calling context.\n" );
 * composed.call();
 *
 * // since each fiber has run to completion, each should have state TERM
 * assert( derived.state == Fiber.State.TERM );
 * assert( composed.state == Fiber.State.TERM );
 *
 * ----------------------------------------------------------------------
 *
 * Authors: Based on a design by Mikola Lysenko.
 */
class Fiber
{
    ///////////////////////////////////////////////////////////////////////////
    // Initialization
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Initializes a fiber object which is associated with a static
     * D function.
     *
     * Params:
     *  fn = The fiber function.
     *  sz = The stack size for this fiber.
     *
     * In:
     *  fn must not be null.
     */
    this( void function() fn, size_t sz = PAGESIZE*4 )
    in
    {
        assert( fn );
    }
    body
    {
        allocStack( sz );
        reset( fn );
    }


    /**
     * Initializes a fiber object which is associated with a dynamic
     * D function.
     *
     * Params:
     *  dg = The fiber function.
     *  sz = The stack size for this fiber.
     *
     * In:
     *  dg must not be null.
     */
    this( void delegate() dg, size_t sz = PAGESIZE*4 )
    in
    {
        assert( dg );
    }
    body
    {
        allocStack( sz );
        reset( dg );
    }


    /**
     * Cleans up any remaining resources used by this object.
     */
    ~this()
    {
        // NOTE: A live reference to this object will exist on its associated
        //       stack from the first time its call() method has been called
        //       until its execution completes with State.TERM.  Thus, the only
        //       times this dtor should be called are either if the fiber has
        //       terminated (and therefore has no active stack) or if the user
        //       explicitly deletes this object.  The latter case is an error
        //       but is not easily tested for, since State.HOLD may imply that
        //       the fiber was just created but has never been run.  There is
        //       not a compelling case to create a State.INIT just to offer a
        //       means of ensuring the user isn't violating this object's
        //       contract, so for now this requirement will be enforced by
        //       documentation only.
        freeStack();
    }


    ///////////////////////////////////////////////////////////////////////////
    // General Actions
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Transfers execution to this fiber object.  The calling context will be
     * suspended until the fiber calls Fiber.yield() or until it terminates
     * via an unhandled exception.
     *
     * Params:
     *  rethrow = Rethrow any unhandled exception which may have caused this
     *            fiber to terminate.
     *
     * In:
     *  This fiber must be in state HOLD.
     *
     * Throws:
     *  Any exception not handled by the joined thread.
     *
     * Returns:
     *  Any exception not handled by this fiber if rethrow = false, null
     *  otherwise.
     */
    final Object call( bool rethrow = true )
    in
    {
        assert( m_state == State.HOLD );
    }
    body
    {
        Fiber   cur = getThis();

        static if( __traits( compiles, ucontext_t ) )
          m_ucur = cur ? &cur.m_utxt : &Fiber.sm_utxt;

        setThis( this );
        this.switchIn();
        setThis( cur );

        static if( __traits( compiles, ucontext_t ) )
          m_ucur = null;

        // NOTE: If the fiber has terminated then the stack pointers must be
        //       reset.  This ensures that the stack for this fiber is not
        //       scanned if the fiber has terminated.  This is necessary to
        //       prevent any references lingering on the stack from delaying
        //       the collection of otherwise dead objects.  The most notable
        //       being the current object, which is referenced at the top of
        //       fiber_entryPoint.
        if( m_state == State.TERM )
        {
            m_ctxt.tstack = m_ctxt.bstack;
        }
        if( m_unhandled )
        {
            Throwable t = m_unhandled;
            m_unhandled = null;
            if( rethrow )
                throw t;
            return t;
        }
        return null;
    }


    /**
     * Resets this fiber so that it may be re-used, optionally with a
     * new function/delegate.  This routine may only be called for
     * fibers that have terminated, as doing otherwise could result in
     * scope-dependent functionality that is not executed.
     * Stack-based classes, for example, may not be cleaned up
     * properly if a fiber is reset before it has terminated.
     *
     * In:
     *  This fiber must be in state TERM.
     */
    final void reset()
    in
    {
        assert( m_state == State.TERM || m_state == State.HOLD );
        assert( m_ctxt.tstack == m_ctxt.bstack );
    }
    body
    {
        m_state = State.HOLD;
        initStack();
        m_unhandled = null;
    }

    /// ditto
    final void reset( void function() fn )
    {
        reset();
        m_fn    = fn;
        m_call  = Call.FN;
    }

    /// ditto
    final void reset( void delegate() dg )
    {
        reset();
        m_dg    = dg;
        m_call  = Call.DG;
    }

    ///////////////////////////////////////////////////////////////////////////
    // General Properties
    ///////////////////////////////////////////////////////////////////////////


    /**
     * A fiber may occupy one of three states: HOLD, EXEC, and TERM.  The HOLD
     * state applies to any fiber that is suspended and ready to be called.
     * The EXEC state will be set for any fiber that is currently executing.
     * And the TERM state is set when a fiber terminates.  Once a fiber
     * terminates, it must be reset before it may be called again.
     */
    enum State
    {
        HOLD,   ///
        EXEC,   ///
        TERM    ///
    }


    /**
     * Gets the current state of this fiber.
     *
     * Returns:
     *  The state of this fiber as an enumerated value.
     */
    final @property State state() const
    {
        return m_state;
    }


    ///////////////////////////////////////////////////////////////////////////
    // Actions on Calling Fiber
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Forces a context switch to occur away from the calling fiber.
     */
    static void yield()
    {
        Fiber   cur = getThis();
        assert( cur, "Fiber.yield() called with no active fiber" );
        assert( cur.m_state == State.EXEC );

        static if( __traits( compiles, ucontext_t ) )
          cur.m_ucur = &cur.m_utxt;

        cur.m_state = State.HOLD;
        cur.switchOut();
        cur.m_state = State.EXEC;
    }


    /**
     * Forces a context switch to occur away from the calling fiber and then
     * throws obj in the calling fiber.
     *
     * Params:
     *  t = The object to throw.
     *
     * In:
     *  t must not be null.
     */
    static void yieldAndThrow( Throwable t )
    in
    {
        assert( t );
    }
    body
    {
        Fiber   cur = getThis();
        assert( cur, "Fiber.yield() called with no active fiber" );
        assert( cur.m_state == State.EXEC );

        static if( __traits( compiles, ucontext_t ) )
          cur.m_ucur = &cur.m_utxt;

        cur.m_unhandled = t;
        cur.m_state = State.HOLD;
        cur.switchOut();
        cur.m_state = State.EXEC;
    }


    ///////////////////////////////////////////////////////////////////////////
    // Fiber Accessors
    ///////////////////////////////////////////////////////////////////////////


    /**
     * Provides a reference to the calling fiber or null if no fiber is
     * currently active.
     *
     * Returns:
     *  The fiber object representing the calling fiber or null if no fiber
     *  is currently active within this thread. The result of deleting this object is undefined.
     */
    static Fiber getThis()
    {
        return sm_this;
    }


    ///////////////////////////////////////////////////////////////////////////
    // Static Initialization
    ///////////////////////////////////////////////////////////////////////////


    version( Posix )
    {
        static this()
        {
            static if( __traits( compiles, ucontext_t ) )
            {
              int status = getcontext( &sm_utxt );
              assert( status == 0 );
            }
        }
    }

private:
    //
    // Initializes a fiber object which has no associated executable function.
    //
    this()
    {
        m_call = Call.NO;
    }


    //
    // Fiber entry point.  Invokes the function or delegate passed on
    // construction (if any).
    //
    final void run()
    {
        switch( m_call )
        {
        case Call.FN:
            m_fn();
            break;
        case Call.DG:
            m_dg();
            break;
        default:
            break;
        }
    }


private:
    //
    // The type of routine passed on fiber construction.
    //
    enum Call
    {
        NO,
        FN,
        DG
    }


    //
    // Standard fiber data
    //
    Call                m_call;
    union
    {
        void function() m_fn;
        void delegate() m_dg;
    }
    bool                m_isRunning;
    Throwable           m_unhandled;
    State               m_state;


private:
    ///////////////////////////////////////////////////////////////////////////
    // Stack Management
    ///////////////////////////////////////////////////////////////////////////


    //
    // Allocate a new stack for this fiber.
    //
    final void allocStack( size_t sz )
    in
    {
        assert( !m_pmem && !m_ctxt );
    }
    body
    {
        // adjust alloc size to a multiple of PAGESIZE
        sz += PAGESIZE - 1;
        sz -= sz % PAGESIZE;

        // NOTE: This instance of Thread.Context is dynamic so Fiber objects
        //       can be collected by the GC so long as no user level references
        //       to the object exist.  If m_ctxt were not dynamic then its
        //       presence in the global context list would be enough to keep
        //       this object alive indefinitely.  An alternative to allocating
        //       room for this struct explicitly would be to mash it into the
        //       base of the stack being allocated below.  However, doing so
        //       requires too much special logic to be worthwhile.
        m_ctxt = new Thread.Context;

        static if( __traits( compiles, VirtualAlloc ) )
        {
            // reserve memory for stack
            m_pmem = VirtualAlloc( null,
                                   sz + PAGESIZE,
                                   MEM_RESERVE,
                                   PAGE_NOACCESS );
            if( !m_pmem )
            {
                throw new FiberException( "Unable to reserve memory for stack" );
            }

            version( StackGrowsDown )
            {
                void* stack = m_pmem + PAGESIZE;
                void* guard = m_pmem;
                void* pbase = stack + sz;
            }
            else
            {
                void* stack = m_pmem;
                void* guard = m_pmem + sz;
                void* pbase = stack;
            }

            // allocate reserved stack segment
            stack = VirtualAlloc( stack,
                                  sz,
                                  MEM_COMMIT,
                                  PAGE_READWRITE );
            if( !stack )
            {
                throw new FiberException( "Unable to allocate memory for stack" );
            }

            // allocate reserved guard page
            guard = VirtualAlloc( guard,
                                  PAGESIZE,
                                  MEM_COMMIT,
                                  PAGE_READWRITE | PAGE_GUARD );
            if( !guard )
            {
                throw new FiberException( "Unable to create guard page for stack" );
            }

            m_ctxt.bstack = pbase;
            m_ctxt.tstack = pbase;
            m_size = sz;
        }
        else
        {
            version (Posix) import core.sys.posix.sys.mman; // mmap
            version (linux) import core.sys.linux.sys.mman : MAP_ANON;

            static if( __traits( compiles, mmap ) )
            {
                m_pmem = mmap( null,
                               sz,
                               PROT_READ | PROT_WRITE,
                               MAP_PRIVATE | MAP_ANON,
                               -1,
                               0 );
                if( m_pmem == MAP_FAILED )
                    m_pmem = null;
            }
            else static if( __traits( compiles, valloc ) )
            {
                m_pmem = valloc( sz );
            }
            else static if( __traits( compiles, malloc ) )
            {
                m_pmem = malloc( sz );
            }
            else
            {
                m_pmem = null;
            }

            if( !m_pmem )
            {
                throw new FiberException( "Unable to allocate memory for stack" );
            }

            version( StackGrowsDown )
            {
                m_ctxt.bstack = m_pmem + sz;
                m_ctxt.tstack = m_pmem + sz;
            }
            else
            {
                m_ctxt.bstack = m_pmem;
                m_ctxt.tstack = m_pmem;
            }
            m_size = sz;
        }

        Thread.add( m_ctxt );
    }


    //
    // Free this fiber's stack.
    //
    final void freeStack()
    in
    {
        assert( m_pmem && m_ctxt );
    }
    body
    {
        // NOTE: m_ctxt is guaranteed to be alive because it is held in the
        //       global context list.
        Thread.remove( m_ctxt );

        static if( __traits( compiles, VirtualAlloc ) )
        {
            VirtualFree( m_pmem, 0, MEM_RELEASE );
        }
        else
        {
            import core.sys.posix.sys.mman; // munmap

            static if( __traits( compiles, mmap ) )
            {
                munmap( m_pmem, m_size );
            }
            else static if( __traits( compiles, valloc ) )
            {
                free( m_pmem );
            }
            else static if( __traits( compiles, malloc ) )
            {
                free( m_pmem );
            }
        }
        m_pmem = null;
        m_ctxt = null;
    }


    //
    // Initialize the allocated stack.
    //
    final void initStack()
    in
    {
        assert( m_ctxt.tstack && m_ctxt.tstack == m_ctxt.bstack );
        assert( cast(size_t) m_ctxt.bstack % (void*).sizeof == 0 );
    }
    body
    {
        void* pstack = m_ctxt.tstack;
        scope( exit )  m_ctxt.tstack = pstack;

        void push( size_t val )
        {
            version( StackGrowsDown )
            {
                pstack -= size_t.sizeof;
                *(cast(size_t*) pstack) = val;
            }
            else
            {
                pstack += size_t.sizeof;
                *(cast(size_t*) pstack) = val;
            }
        }

        // NOTE: On OS X the stack must be 16-byte aligned according
        // to the IA-32 call spec. For x86_64 the stack also needs to
        // be aligned to 16-byte according to SysV AMD64 ABI.
        version( AlignFiberStackTo16Byte )
        {
            version( StackGrowsDown )
            {
                pstack = cast(void*)(cast(size_t)(pstack) - (cast(size_t)(pstack) & 0x0F));
            }
            else
            {
                pstack = cast(void*)(cast(size_t)(pstack) + (cast(size_t)(pstack) & 0x0F));
            }
        }

        version( AsmX86_Windows )
        {
            version( StackGrowsDown ) {} else static assert( false );

            // On Windows Server 2008 and 2008 R2, an exploit mitigation
            // technique known as SEHOP is activated by default. To avoid
            // hijacking of the exception handler chain, the presence of a
            // Windows-internal handler (ntdll.dll!FinalExceptionHandler) at
            // its end is tested by RaiseException. If it is not present, all
            // handlers are disregarded, and the program is thus aborted
            // (see http://blogs.technet.com/b/srd/archive/2009/02/02/
            // preventing-the-exploitation-of-seh-overwrites-with-sehop.aspx).
            // For new threads, this handler is installed by Windows immediately
            // after creation. To make exception handling work in fibers, we
            // have to insert it for our new stacks manually as well.
            //
            // To do this, we first determine the handler by traversing the SEH
            // chain of the current thread until its end, and then construct a
            // registration block for the last handler on the newly created
            // thread. We then continue to push all the initial register values
            // for the first context switch as for the other implementations.
            //
            // Note that this handler is never actually invoked, as we install
            // our own one on top of it in the fiber entry point function.
            // Thus, it should not have any effects on OSes not implementing
            // exception chain verification.

            alias void function() fp_t; // Actual signature not relevant.
            static struct EXCEPTION_REGISTRATION
            {
                EXCEPTION_REGISTRATION* next; // sehChainEnd if last one.
                fp_t handler;
            }
            enum sehChainEnd = cast(EXCEPTION_REGISTRATION*) 0xFFFFFFFF;

            __gshared static fp_t finalHandler = null;
            if ( finalHandler is null )
            {
                static EXCEPTION_REGISTRATION* fs0()
                {
                    asm
                    {
                        naked;
                        mov EAX, FS:[0];
                        ret;
                    }
                }
                auto reg = fs0();
                while ( reg.next != sehChainEnd ) reg = reg.next;

                // Benign races are okay here, just to avoid re-lookup on every
                // fiber creation.
                finalHandler = reg.handler;
            }

            pstack -= EXCEPTION_REGISTRATION.sizeof;
            *(cast(EXCEPTION_REGISTRATION*)pstack) =
                EXCEPTION_REGISTRATION( sehChainEnd, finalHandler );

            push( cast(size_t) &fiber_entryPoint );                 // EIP
            push( cast(size_t) m_ctxt.bstack - EXCEPTION_REGISTRATION.sizeof ); // EBP
            push( 0x00000000 );                                     // EDI
            push( 0x00000000 );                                     // ESI
            push( 0x00000000 );                                     // EBX
            push( cast(size_t) m_ctxt.bstack - EXCEPTION_REGISTRATION.sizeof ); // FS:[0]
            push( cast(size_t) m_ctxt.bstack );                     // FS:[4]
            push( cast(size_t) m_ctxt.bstack - m_size );            // FS:[8]
            push( 0x00000000 );                                     // EAX
        }
        else version( AsmX86_64_Windows )
        {
            push( 0x00000000_00000000 );                            // Return address of fiber_entryPoint call
            push( cast(size_t) &fiber_entryPoint );                 // RIP
            push( 0x00000000_00000000 );                            // RBP
            push( 0x00000000_00000000 );                            // RBX
            push( 0x00000000_00000000 );                            // R12
            push( 0x00000000_00000000 );                            // R13
            push( 0x00000000_00000000 );                            // R14
            push( 0x00000000_00000000 );                            // R15
            push( 0xFFFFFFFF_FFFFFFFF );                            // GS:[0]
            version( StackGrowsDown )
            {
                push( cast(size_t) m_ctxt.bstack );                 // GS:[8]
                push( cast(size_t) m_ctxt.bstack - m_size );        // GS:[16]
            }
            else
            {
                push( cast(size_t) m_ctxt.bstack );                 // GS:[8]
                push( cast(size_t) m_ctxt.bstack + m_size );        // GS:[16]
            }
        }
        else version( AsmX86_Posix )
        {
            push( 0x00000000 );                                     // Return address of fiber_entryPoint call
            push( cast(size_t) &fiber_entryPoint );                 // EIP
            push( cast(size_t) m_ctxt.bstack );                     // EBP
            push( 0x00000000 );                                     // EDI
            push( 0x00000000 );                                     // ESI
            push( 0x00000000 );                                     // EBX
            push( 0x00000000 );                                     // EAX
        }
        else version( AsmX86_64_Posix )
        {
            push( 0x00000000_00000000 );                            // Return address of fiber_entryPoint call
            push( cast(size_t) &fiber_entryPoint );                 // RIP
            push( cast(size_t) m_ctxt.bstack );                     // RBP
            push( 0x00000000_00000000 );                            // RBX
            push( 0x00000000_00000000 );                            // R12
            push( 0x00000000_00000000 );                            // R13
            push( 0x00000000_00000000 );                            // R14
            push( 0x00000000_00000000 );                            // R15
        }
        else version( AsmPPC_Posix )
        {
            version( StackGrowsDown )
            {
                pstack -= int.sizeof * 5;
            }
            else
            {
                pstack += int.sizeof * 5;
            }

            push( cast(size_t) &fiber_entryPoint );     // link register
            push( 0x00000000 );                         // control register
            push( 0x00000000 );                         // old stack pointer

            // GPR values
            version( StackGrowsDown )
            {
                pstack -= int.sizeof * 20;
            }
            else
            {
                pstack += int.sizeof * 20;
            }

            assert( (cast(size_t) pstack & 0x0f) == 0 );
        }
        else version( AsmMIPS_O32_Posix )
        {
            version (StackGrowsDown) {}
            else static assert(0);

            /* We keep the FP registers and the return address below
             * the stack pointer, so they don't get scanned by the
             * GC. The last frame before swapping the stack pointer is
             * organized like the following.
             *
             *     |-----------|<= frame pointer
             *     |    $gp    |
             *     |   $s0-8   |
             *     |-----------|<= stack pointer
             *     |    $ra    |
             *     |  align(8) |
             *     |  $f20-30  |
             *     |-----------|
             *
             */
            enum SZ_GP = 10 * size_t.sizeof; // $gp + $s0-8
            enum SZ_RA = size_t.sizeof;      // $ra
            version (MIPS_HardFloat)
            {
                enum SZ_FP = 6 * 8;          // $f20-30
                enum ALIGN = -(SZ_FP + SZ_RA) & (8 - 1);
            }
            else
            {
                enum SZ_FP = 0;
                enum ALIGN = 0;
            }

            enum BELOW = SZ_FP + ALIGN + SZ_RA;
            enum ABOVE = SZ_GP;
            enum SZ = BELOW + ABOVE;

            (cast(ubyte*)pstack - SZ)[0 .. SZ] = 0;
            pstack -= ABOVE;
            *cast(size_t*)(pstack - SZ_RA) = cast(size_t)&fiber_entryPoint;
        }
        else static if( __traits( compiles, ucontext_t ) )
        {
            getcontext( &m_utxt );
            m_utxt.uc_stack.ss_sp   = m_pmem;
            m_utxt.uc_stack.ss_size = m_size;
            makecontext( &m_utxt, &fiber_entryPoint, 0 );
            // NOTE: If ucontext is being used then the top of the stack will
            //       be a pointer to the ucontext_t struct for that fiber.
            push( cast(size_t) &m_utxt );
        }
        else
            static assert(0, "Not implemented");
    }


    Thread.Context* m_ctxt;
    size_t          m_size;
    void*           m_pmem;

    static if( __traits( compiles, ucontext_t ) )
    {
        // NOTE: The static ucontext instance is used to represent the context
        //       of the executing thread.
        static ucontext_t       sm_utxt = void;
        ucontext_t              m_utxt  = void;
        ucontext_t*             m_ucur  = null;
    }


private:
    ///////////////////////////////////////////////////////////////////////////
    // Storage of Active Fiber
    ///////////////////////////////////////////////////////////////////////////


    //
    // Sets a thread-local reference to the current fiber object.
    //
    static void setThis( Fiber f )
    {
        sm_this = f;
    }

    static Fiber sm_this;


private:
    ///////////////////////////////////////////////////////////////////////////
    // Context Switching
    ///////////////////////////////////////////////////////////////////////////


    //
    // Switches into the stack held by this fiber.
    //
    final void switchIn()
    {
        Thread  tobj = Thread.getThis();
        void**  oldp = &tobj.m_curr.tstack;
        void*   newp = m_ctxt.tstack;

        // NOTE: The order of operations here is very important.  The current
        //       stack top must be stored before m_lock is set, and pushContext
        //       must not be called until after m_lock is set.  This process
        //       is intended to prevent a race condition with the suspend
        //       mechanism used for garbage collection.  If it is not followed,
        //       a badly timed collection could cause the GC to scan from the
        //       bottom of one stack to the top of another, or to miss scanning
        //       a stack that still contains valid data.  The old stack pointer
        //       oldp will be set again before the context switch to guarantee
        //       that it points to exactly the correct stack location so the
        //       successive pop operations will succeed.
        *oldp = getStackTop();
        atomicStore!(MemoryOrder.raw)(*cast(shared)&tobj.m_lock, true);
        tobj.pushContext( m_ctxt );

        fiber_switchContext( oldp, newp );

        // NOTE: As above, these operations must be performed in a strict order
        //       to prevent Bad Things from happening.
        tobj.popContext();
        atomicStore!(MemoryOrder.raw)(*cast(shared)&tobj.m_lock, false);
        tobj.m_curr.tstack = tobj.m_curr.bstack;
    }


    //
    // Switches out of the current stack and into the enclosing stack.
    //
    final void switchOut()
    {
        Thread  tobj = Thread.getThis();
        void**  oldp = &m_ctxt.tstack;
        void*   newp = tobj.m_curr.within.tstack;

        // NOTE: The order of operations here is very important.  The current
        //       stack top must be stored before m_lock is set, and pushContext
        //       must not be called until after m_lock is set.  This process
        //       is intended to prevent a race condition with the suspend
        //       mechanism used for garbage collection.  If it is not followed,
        //       a badly timed collection could cause the GC to scan from the
        //       bottom of one stack to the top of another, or to miss scanning
        //       a stack that still contains valid data.  The old stack pointer
        //       oldp will be set again before the context switch to guarantee
        //       that it points to exactly the correct stack location so the
        //       successive pop operations will succeed.
        *oldp = getStackTop();
        atomicStore!(MemoryOrder.raw)(*cast(shared)&tobj.m_lock, true);

        fiber_switchContext( oldp, newp );

        // NOTE: As above, these operations must be performed in a strict order
        //       to prevent Bad Things from happening.
        // NOTE: If use of this fiber is multiplexed across threads, the thread
        //       executing here may be different from the one above, so get the
        //       current thread handle before unlocking, etc.
        tobj = Thread.getThis();
        atomicStore!(MemoryOrder.raw)(*cast(shared)&tobj.m_lock, false);
        tobj.m_curr.tstack = tobj.m_curr.bstack;
    }
}

// These must be kept in sync with core/thread.di
version (GNU) {} else
version (D_LP64)
{
    version (Windows)
        static assert(__traits(classInstanceSize, Fiber) == 88);
    else version (OSX)
        static assert(__traits(classInstanceSize, Fiber) == 88);
    else version (Posix)
    {
        static if( __traits( compiles, ucontext_t ) )
            static assert(__traits(classInstanceSize, Fiber) == 88 + ucontext_t.sizeof + 8);
        else
            static assert(__traits(classInstanceSize, Fiber) == 88);
    }
    else
        static assert(0, "Platform not supported.");
}
else
{
    static assert((void*).sizeof == 4); // 32-bit

    version (Windows)
        static assert(__traits(classInstanceSize, Fiber) == 44);
    else version (OSX)
        static assert(__traits(classInstanceSize, Fiber) == 44);
    else version (Posix)
    {
        static if( __traits( compiles, ucontext_t ) )
        {
            // ucontext_t might have an alignment larger than 4.
            static roundUp()(size_t n)
            {
                return (n + (ucontext_t.alignof - 1)) & ~(ucontext_t.alignof - 1);
            }
            static assert(__traits(classInstanceSize, Fiber) ==
                roundUp(roundUp(44) + ucontext_t.sizeof + 4));
        }
        else
            static assert(__traits(classInstanceSize, Fiber) == 44);
    }
    else
        static assert(0, "Platform not supported.");
}


version(Win64) {}
else {

version( unittest )
{
    class TestFiber : Fiber
    {
        this()
        {
            super(&run);
        }

        void run()
        {
            foreach(i; 0 .. 1000)
            {
                sum += i;
                Fiber.yield();
            }
        }

        enum expSum = 1000 * 999 / 2;
        size_t sum;
    }

    void runTen()
    {
        TestFiber[10] fibs;
        foreach(ref fib; fibs)
            fib = new TestFiber();

        bool cont;
        do {
            cont = false;
            foreach(fib; fibs) {
                if (fib.state == Fiber.State.HOLD)
                {
                    fib.call();
                    cont |= fib.state != Fiber.State.TERM;
                }
            }
        } while (cont);

        foreach(fib; fibs)
        {
            assert(fib.sum == TestFiber.expSum);
        }
    }
}


// Single thread running separate fibers
unittest
{
    runTen();
}


// Multiple threads running separate fibers
unittest
{
    auto group = new ThreadGroup();
    foreach(_; 0 .. 4)
    {
        group.create(&runTen);
    }
    group.joinAll();
}


// Multiple threads running shared fibers
unittest
{
    shared bool[10] locks;
    TestFiber[10] fibs;

    void runShared()
    {
        bool cont;
        do {
            cont = false;
            foreach(idx; 0 .. 10)
            {
                if (cas(&locks[idx], false, true))
                {
                    if (fibs[idx].state == Fiber.State.HOLD)
                    {
                        fibs[idx].call();
                        cont |= fibs[idx].state != Fiber.State.TERM;
                    }
                    locks[idx] = false;
                }
                else
                {
                    cont = true;
                }
            }
        } while (cont);
    }

    foreach(ref fib; fibs)
    {
        fib = new TestFiber();
    }

    auto group = new ThreadGroup();
    foreach(_; 0 .. 4)
    {
        group.create(&runShared);
    }
    group.joinAll();

    foreach(fib; fibs)
    {
        assert(fib.sum == TestFiber.expSum);
    }
}


// Test exception handling inside fibers.
unittest
{
    enum MSG = "Test message.";
    string caughtMsg;
    (new Fiber({
        try
        {
            throw new Exception(MSG);
        }
        catch (Exception e)
        {
            caughtMsg = e.msg;
        }
    })).call();
    assert(caughtMsg == MSG);
}


unittest
{
    int x = 0;

    (new Fiber({
        x++;
    })).call();
    assert( x == 1 );
}


unittest
{
    enum MSG = "Test message.";

    try
    {
        (new Fiber({
            throw new Exception( MSG );
        })).call();
        assert( false, "Expected rethrown exception." );
    }
    catch( Throwable t )
    {
        assert( t.msg == MSG );
    }
}


// Test Fiber resetting
unittest
{
    static string method;

    static void foo()
    {
        method = "foo";
    }

    void bar()
    {
        method = "bar";
    }

    static void expect(Fiber fib, string s)
    {
        assert(fib.state == Fiber.State.HOLD);
        fib.call();
        assert(fib.state == Fiber.State.TERM);
        assert(method == s); method = null;
    }
    auto fib = new Fiber(&foo);
    expect(fib, "foo");

    fib.reset();
    expect(fib, "foo");

    fib.reset(&foo);
    expect(fib, "foo");

    fib.reset(&bar);
    expect(fib, "bar");

    fib.reset(function void(){method = "function";});
    expect(fib, "function");

    fib.reset(delegate void(){method = "delegate";});
    expect(fib, "delegate");
}


// stress testing GC stack scanning
unittest
{
    import core.memory;

    static void unreferencedThreadObject()
    {
        static void sleep() { Thread.sleep(dur!"msecs"(100)); }
        auto thread = new Thread(&sleep);
        thread.start();
    }
    unreferencedThreadObject();
    GC.collect();

    static class Foo
    {
        this(int value)
        {
            _value = value;
        }

        int bar()
        {
            return _value;
        }

        int _value;
    }

    static void collect()
    {
        auto foo = new Foo(2);
        assert(foo.bar() == 2);
        GC.collect();
        Fiber.yield();
        GC.collect();
        assert(foo.bar() == 2);
    }

    auto fiber = new Fiber(&collect);

    fiber.call();
    GC.collect();
    fiber.call();

    // thread reference
    auto foo = new Foo(2);

    void collect2()
    {
        assert(foo.bar() == 2);
        GC.collect();
        Fiber.yield();
        GC.collect();
        assert(foo.bar() == 2);
    }

    fiber = new Fiber(&collect2);

    fiber.call();
    GC.collect();
    fiber.call();

    static void recurse(size_t cnt)
    {
        --cnt;
        Fiber.yield();
        if (cnt)
        {
            auto fib = new Fiber(() { recurse(cnt); });
            fib.call();
            GC.collect();
            fib.call();
        }
    }
    fiber = new Fiber(() { recurse(20); });
    fiber.call();
}

}

version( AsmX86_64_Posix )
{
    unittest
    {
        void testStackAlignment()
        {
            void* pRSP;
            asm
            {
                mov pRSP, RSP;
            }
            assert((cast(size_t)pRSP & 0xF) == 0);
        }

        auto fib = new Fiber(&testStackAlignment);
        fib.call();
    }
}
