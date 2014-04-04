/**
 * D header file for C99.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly,
              Alex Rønne Petersen
 * Standards: ISO/IEC 9899:1999 (E)
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.stdc.stdio;

version(BareMetal) {}

else:

private
{
    import core.stdc.config;
    import core.stdc.stddef; // for size_t
    import core.stdc.stdarg; // for va_list

  version (FreeBSD)
  {
    import core.sys.posix.sys.types;
  }
}

extern (C):
@system:
nothrow:

version( Win32 )
{
    enum
    {
        BUFSIZ       = 0x4000,
        EOF          = -1,
        FOPEN_MAX    = 20,
        FILENAME_MAX = 256, // 255 plus NULL
        TMP_MAX      = 32767,
        SYS_OPEN     = 20,      // non-standard
    }

    enum int     _NFILE     = 60;       // non-standard
    enum string  _P_tmpdir  = "\\"; // non-standard
    enum wstring _wP_tmpdir = "\\"; // non-standard
    enum int     L_tmpnam   = _P_tmpdir.length + 12;
}
else version( Win64 )
{
    enum
    {
        BUFSIZ       = 512,
        EOF          = -1,
        FOPEN_MAX    = 20,
        FILENAME_MAX = 260,
        TMP_MAX      = 32767,
        _SYS_OPEN    = 20,      // non-standard
    }

    enum int     _NFILE     = 512;       // non-standard
    enum string  _P_tmpdir  = "\\"; // non-standard
    enum wstring _wP_tmpdir = "\\"; // non-standard
    enum int     L_tmpnam   = _P_tmpdir.length + 12;
}
else version( linux )
{
    enum
    {
        BUFSIZ       = 8192,
        EOF          = -1,
        FOPEN_MAX    = 16,
        FILENAME_MAX = 4095,
        TMP_MAX      = 238328,
        L_tmpnam     = 20
    }
}
else version( OSX )
{
    enum
    {
        BUFSIZ       = 1024,
        EOF          = -1,
        FOPEN_MAX    = 20,
        FILENAME_MAX = 1024,
        TMP_MAX      = 308915776,
        L_tmpnam     = 1024,
    }

    private
    {
        struct __sbuf
        {
            ubyte*  _base;
            int     _size;
        }

        struct __sFILEX
        {

        }
    }
}
else version ( FreeBSD )
{
    enum
    {
        BUFSIZ       = 1024,
        EOF          = -1,
        FOPEN_MAX    = 20,
        FILENAME_MAX = 1024,
        TMP_MAX      = 308915776,
        L_tmpnam     = 1024
    }

    struct __sbuf
    {
        ubyte *_base;
        int _size;
    }
    alias _iobuf __sFILE;

    union __mbstate_t // <sys/_types.h>
    {
        char[128]   _mbstate8;
        long        _mbstateL;
    }
}
else version (Solaris)
{
    enum
    {
        BUFSIZ = 1024,
        EOF = -1,
        FOPEN_MAX = _NFILE,
        FILENAME_MAX = 1024,
        TMP_MAX = 17576,
        L_tmpnam = 25,
    }

    version (X86)
        enum int _NFILE = 60;
    else
        enum int _NFILE = 20;
}
else
{
    static assert( false, "Unsupported platform" );
}

enum
{
    SEEK_SET,
    SEEK_CUR,
    SEEK_END
}

version( Win32 )
{
    struct _iobuf
    {
        char* _ptr;
        int   _cnt;
        char* _base;
        int   _flag;
        int   _file;
        int   _charbuf;
        int   _bufsiz;
        char* __tmpnum;
    }
}
else version( Win64 )
{
    struct _iobuf
    {
        char* _ptr;
        int   _cnt;
        char* _base;
        int   _flag;
        int   _file;
        int   _charbuf;
        int   _bufsiz;
        char* _tmpfname;
    }
}
else version( linux )
{
    alias _iobuf = _IO_FILE;

    align(1) struct _IO_FILE
    {
        int     _flags;
        char*   _read_ptr;
        char*   _read_end;
        char*   _read_base;
        char*   _write_base;
        char*   _write_ptr;
        char*   _write_end;
        char*   _buf_base;
        char*   _buf_end;
        char*   _save_base;
        char*   _backup_base;
        char*   _save_end;
        void*   _markers;
        _iobuf* _chain;
        int     _fileno;
        int     _blksize;
        int     _old_offset;
        ushort  _cur_column;
        byte    _vtable_offset;
        char[1] _shortbuf;
        void*   _lock;
    }
}
else version( OSX )
{
    align (1) struct _iobuf
    {
        ubyte*    _p;
        int       _r;
        int       _w;
        short     _flags;
        short     _file;
        __sbuf    _bf;
        int       _lbfsize;

        int* function(void*)                    _close;
        int* function(void*, char*, int)        _read;
        fpos_t* function(void*, fpos_t, int)    _seek;
        int* function(void*, char *, int)       _write;

        __sbuf    _ub;
        __sFILEX* _extra;
        int       _ur;

        ubyte[3]  _ubuf;
        ubyte[1]  _nbuf;

        __sbuf    _lb;

        int       _blksize;
        fpos_t    _offset;
    }
}
else version( FreeBSD )
{
    align (1) struct _iobuf
    {
        ubyte*          _p;
        int             _r;
        int             _w;
        short           _flags;
        short           _file;
        __sbuf          _bf;
        int             _lbfsize;

        void*           _cookie;
        int     function(void*)                 _close;
        int     function(void*, char*, int)     _read;
        fpos_t  function(void*, fpos_t, int)    _seek;
        int     function(void*, in char*, int)  _write;

        __sbuf          _ub;
        ubyte*          _up;
        int             _ur;

        ubyte[3]        _ubuf;
        ubyte[1]        _nbuf;

        __sbuf          _lb;

        int             _blksize;
        fpos_t          _offset;

        pthread_mutex_t _fl_mutex;
        pthread_t       _fl_owner;
        int             _fl_count;
        int             _orientation;
        __mbstate_t     _mbstate;
    }
}
else version (Solaris)
{
    align (1) struct _iobuf
    {
        char* _ptr;
        int _cnt;
        char* _base;
        char _flag;
        char _magic;
        ushort __flags; // __orientation:2
                        // __ionolock:1
                        // __seekable:1
                        // __extendedfd:1
                        // __xf_nocheck:1
                        // __filler:10
    }
}
else
{
    static assert( false, "Unsupported platform" );
}


alias shared(_iobuf) FILE;

enum
{
    _F_RDWR = 0x0003, // non-standard
    _F_READ = 0x0001, // non-standard
    _F_WRIT = 0x0002, // non-standard
    _F_BUF  = 0x0004, // non-standard
    _F_LBUF = 0x0008, // non-standard
    _F_ERR  = 0x0010, // non-standard
    _F_EOF  = 0x0020, // non-standard
    _F_BIN  = 0x0040, // non-standard
    _F_IN   = 0x0080, // non-standard
    _F_OUT  = 0x0100, // non-standard
    _F_TERM = 0x0200, // non-standard
}

version( Win32 )
{
    enum
    {
        _IOFBF   = 0,
        _IOLBF   = 0x40,
        _IONBF   = 4,
        _IOREAD  = 1,     // non-standard
        _IOWRT   = 2,     // non-standard
        _IOMYBUF = 8,     // non-standard
        _IOEOF   = 0x10,  // non-standard
        _IOERR   = 0x20,  // non-standard
        _IOSTRG  = 0x40,  // non-standard
        _IORW    = 0x80,  // non-standard
        _IOTRAN  = 0x100, // non-standard
        _IOAPP   = 0x200, // non-standard
    }

  version( MinGW )
  {
    private extern
    {
       __gshared export FILE[5] _iob;
    }

    __gshared FILE* stdin;
    __gshared FILE* stdout;
    __gshared FILE* stderr;

    shared static this()
    {
        stdin  = &_iob[0];
        stdout = &_iob[1];
        stderr = &_iob[2];
    }
  }
  else
  {
    extern shared void function() _fcloseallp;

    private extern shared FILE[_NFILE] _iob;

    shared stdin  = &_iob[0];
    shared stdout = &_iob[1];
    shared stderr = &_iob[2];
    shared stdaux = &_iob[3];
    shared stdprn = &_iob[4];
  }
}
else version( Win64 )
{
    enum
    {
        _IOFBF   = 0,
        _IOLBF   = 0x40,
        _IONBF   = 4,
        _IOREAD  = 1,     // non-standard
        _IOWRT   = 2,     // non-standard
        _IOMYBUF = 8,     // non-standard
        _IOEOF   = 0x10,  // non-standard
        _IOERR   = 0x20,  // non-standard
        _IOSTRG  = 0x40,  // non-standard
        _IORW    = 0x80,  // non-standard
        _IOAPP   = 0x200, // non-standard
        _IOAPPEND = 0x200, // non-standard
    }

    extern shared void function() _fcloseallp;

    private extern shared FILE[_NFILE] _iob;

    shared(FILE)* __iob_func();

    shared FILE* stdin;  // = &__iob_func()[0];
    shared FILE* stdout; // = &__iob_func()[1];
    shared FILE* stderr; // = &__iob_func()[2];
}
else version( linux )
{
    enum
    {
        _IOFBF = 0,
        _IOLBF = 1,
        _IONBF = 2,
    }

    extern shared FILE* stdin;
    extern shared FILE* stdout;
    extern shared FILE* stderr;
}
else version( OSX )
{
    enum
    {
        _IOFBF = 0,
        _IOLBF = 1,
        _IONBF = 2,
    }

    private extern shared FILE* __stdinp;
    private extern shared FILE* __stdoutp;
    private extern shared FILE* __stderrp;

    alias __stdinp  stdin;
    alias __stdoutp stdout;
    alias __stderrp stderr;
}
else version( FreeBSD )
{
    enum
    {
        _IOFBF = 0,
        _IOLBF = 1,
        _IONBF = 2,
    }

    private extern shared FILE* __stdinp;
    private extern shared FILE* __stdoutp;
    private extern shared FILE* __stderrp;

    alias __stdinp  stdin;
    alias __stdoutp stdout;
    alias __stderrp stderr;
}
else version (Solaris)
{
    enum
    {
        _IOFBF = 0x00,
        _IOLBF = 0x40,
        _IONBF = 0x04,
        _IOEOF = 0x20,
        _IOERR = 0x40,
        _IOREAD = 0x01,
        _IOWRT = 0x02,
        _IORW = 0x80,
        _IOMYBUF = 0x08,
    }

    private extern shared FILE[_NFILE] __iob;

    shared stdin = &__iob[0];
    shared stdout = &__iob[1];
    shared stderr = &__iob[2];
}
else version( GNU_CBridge_Stdio )
{
    extern FILE * _d_gnu_cbridge_stdin;
    extern FILE * _d_gnu_cbridge_stdout;
    extern FILE * _d_gnu_cbridge_stderr;
    
    extern void _d_gnu_cbridge_init_stdio();

    shared static this()
    {
        _d_gnu_cbridge_init_stdio();
    }

    alias _d_gnu_cbridge_stdin stdin;
    alias _d_gnu_cbridge_stdout stdout;
    alias _d_gnu_cbridge_stderr stderr;
}
else
{
    static assert( false, "Unsupported platform" );
}

alias int fpos_t;

int remove(in char* filename);
int rename(in char* from, in char* to);

@trusted FILE* tmpfile(); // No unsafe pointer manipulation.
char* tmpnam(char* s);

int   fclose(FILE* stream);

// No unsafe pointer manipulation.
@trusted
{
    int   fflush(FILE* stream);
}

FILE* fopen(in char* filename, in char* mode);
FILE* freopen(in char* filename, in char* mode, FILE* stream);

void setbuf(FILE* stream, char* buf);
int  setvbuf(FILE* stream, char* buf, int mode, size_t size);

version (MinGW)
{
    // Prefer the MinGW versions over the MSVC ones, as the latter don't handle
    // reals at all.
    int __mingw_fprintf(FILE* stream, in char* format, ...);
    alias __mingw_fprintf fprintf;

    int __mingw_fscanf(FILE* stream, in char* format, ...);
    alias __mingw_fscanf fscanf;

    int __mingw_sprintf(char* s, in char* format, ...);
    alias __mingw_sprintf sprintf;

    int __mingw_sscanf(in char* s, in char* format, ...);
    alias __mingw_sscanf sscanf;

    int __mingw_vfprintf(FILE* stream, in char* format, va_list arg);
    alias __mingw_vfprintf vfprintf;

    int __mingw_vfscanf(FILE* stream, in char* format, va_list arg);
    alias __mingw_vfscanf vfscanf;

    int __mingw_vsprintf(char* s, in char* format, va_list arg);
    alias __mingw_vsprintf vsprintf;

    int __mingw_vsscanf(in char* s, in char* format, va_list arg);
    alias __mingw_vsscanf vsscanf;

    int __mingw_vprintf(in char* format, va_list arg);
    alias __mingw_vprintf vprintf;

    int __mingw_vscanf(in char* format, va_list arg);
    alias __mingw_vscanf vscanf;

    int __mingw_printf(in char* format, ...);
    alias __mingw_printf printf;

    int __mingw_scanf(in char* format, ...);
    alias __mingw_scanf scanf;
}
else
{
    int fprintf(FILE* stream, in char* format, ...);
    int fscanf(FILE* stream, in char* format, ...);
    int sprintf(char* s, in char* format, ...);
    int sscanf(in char* s, in char* format, ...);
    int vfprintf(FILE* stream, in char* format, va_list arg);
    int vfscanf(FILE* stream, in char* format, va_list arg);
    int vsprintf(char* s, in char* format, va_list arg);
    int vsscanf(in char* s, in char* format, va_list arg);
    int vprintf(in char* format, va_list arg);
    int vscanf(in char* format, va_list arg);
    int printf(in char* format, ...);
    int scanf(in char* format, ...);
}

// No usafe pointer manipulation.
@trusted
{
    int fgetc(FILE* stream);
    int fputc(int c, FILE* stream);
}

char* fgets(char* s, int n, FILE* stream);
int   fputs(in char* s, FILE* stream);
char* gets(char* s);
int   puts(in char* s);

// No unsafe pointer manipulation.
extern (D) @trusted
{
    int getchar()                 { return getc(stdin);     }
    int putchar(int c)            { return putc(c,stdout);  }
    int getc(FILE* stream)        { return fgetc(stream);   }
    int putc(int c, FILE* stream) { return fputc(c,stream); }
}

@trusted int ungetc(int c, FILE* stream); // No unsafe pointer manipulation.

size_t fread(void* ptr, size_t size, size_t nmemb, FILE* stream);
size_t fwrite(in void* ptr, size_t size, size_t nmemb, FILE* stream);

// No unsafe pointer manipulation.
@trusted
{
    int fgetpos(FILE* stream, fpos_t * pos);
    int fsetpos(FILE* stream, in fpos_t* pos);

    int    fseek(FILE* stream, c_long offset, int whence);
    c_long ftell(FILE* stream);
}

version( MinGW )
{
  // No unsafe pointer manipulation.
  extern (D) @trusted
  {
    void rewind(FILE* stream)   { fseek(stream,0L,SEEK_SET); stream._flag&=~_IOERR; }
    pure void clearerr(FILE* stream) { stream._flag &= ~(_IOERR|_IOEOF);                 }
    pure int  feof(FILE* stream)     { return stream._flag&_IOEOF;                       }
    pure int  ferror(FILE* stream)   { return stream._flag&_IOERR;                       }
  }
    int   __mingw_snprintf(char* s, size_t n, in char* fmt, ...);
    alias __mingw_snprintf _snprintf;
    alias __mingw_snprintf snprintf;

    int   __mingw_vsnprintf(char* s, size_t n, in char* format, va_list arg);
    alias __mingw_vsnprintf _vsnprintf;
    alias __mingw_vsnprintf vsnprintf;
}
else version( Win32 )
{
  // No unsafe pointer manipulation.
  extern (D) @trusted
  {
    void rewind(FILE* stream)   { fseek(stream,0L,SEEK_SET); stream._flag&=~_IOERR; }
    pure void clearerr(FILE* stream) { stream._flag &= ~(_IOERR|_IOEOF);                 }
    pure int  feof(FILE* stream)     { return stream._flag&_IOEOF;                       }
    pure int  ferror(FILE* stream)   { return stream._flag&_IOERR;                       }
  }
    int   _snprintf(char* s, size_t n, in char* fmt, ...);
    alias _snprintf snprintf;

    int   _vsnprintf(char* s, size_t n, in char* format, va_list arg);
    alias _vsnprintf vsnprintf;
}
else version( Win64 )
{
  // No unsafe pointer manipulation.
  extern (D) @trusted
  {
    void rewind(FILE* stream)   { fseek(stream,0L,SEEK_SET); stream._flag&=~_IOERR; }
    pure void clearerr(FILE* stream) { stream._flag &= ~(_IOERR|_IOEOF);                 }
    pure int  feof(FILE* stream)     { return stream._flag&_IOEOF;                       }
    pure int  ferror(FILE* stream)   { return stream._flag&_IOERR;                       }
    pure int  fileno(FILE* stream)   { return stream._file;                              }
  }
    int   _snprintf(char* s, size_t n, in char* fmt, ...);
    alias _snprintf snprintf;

    int   _vsnprintf(char* s, size_t n, in char* format, va_list arg);
    alias _vsnprintf vsnprintf;

    uint _set_output_format(uint format);
    enum _TWO_DIGIT_EXPONENT = 1;

    int _filbuf(FILE *fp);
    int _flsbuf(int c, FILE *fp);

    int _fputc_nolock(int c, FILE *fp)
    {
        if (--fp._cnt >= 0)
            return *fp._ptr++ = cast(char)c;
        else
            return _flsbuf(c, fp);
    }

    int _fgetc_nolock(FILE *fp)
    {
        if (--fp._cnt >= 0)
            return *fp._ptr++;
        else
            return _filbuf(fp);
    }

    int _lock_file(FILE *fp);
    int _unlock_file(FILE *fp);
}
else version( linux )
{
  // No unsafe pointer manipulation.
  @trusted
  {
    void rewind(FILE* stream);
    pure void clearerr(FILE* stream);
    pure int  feof(FILE* stream);
    pure int  ferror(FILE* stream);
    int  fileno(FILE *);
  }

    int  snprintf(char* s, size_t n, in char* format, ...);
    int  vsnprintf(char* s, size_t n, in char* format, va_list arg);
}
else version( OSX )
{
  // No unsafe pointer manipulation.
  @trusted
  {
    void rewind(FILE*);
    pure void clearerr(FILE*);
    pure int  feof(FILE*);
    pure int  ferror(FILE*);
    int  fileno(FILE*);
  }

    int  snprintf(char* s, size_t n, in char* format, ...);
    int  vsnprintf(char* s, size_t n, in char* format, va_list arg);
}
else version( FreeBSD )
{
  // No unsafe pointer manipulation.
  @trusted
  {
    void rewind(FILE*);
    pure void clearerr(FILE*);
    pure int  feof(FILE*);
    pure int  ferror(FILE*);
    int  fileno(FILE*);
  }

    int  snprintf(char* s, size_t n, in char* format, ...);
    int  vsnprintf(char* s, size_t n, in char* format, va_list arg);
}
else version (Solaris)
{
  // No unsafe pointer manipulation.
  @trusted
  {
    void rewind(FILE*);
    pure void clearerr(FILE*);
    pure int  feof(FILE*);
    pure int  ferror(FILE*);
    int  fileno(FILE*);
  }

    int  snprintf(char* s, size_t n, in char* format, ...);
    int  vsnprintf(char* s, size_t n, in char* format, va_list arg);
}
else version( GNU )
{
  // No unsafe pointer manipulation.
  @trusted
  {
    void rewind(FILE*);
    pure void clearerr(FILE*);
    pure int  feof(FILE*);
    pure int  ferror(FILE*);
    int  fileno(FILE*);
  }

    int  snprintf(char* s, size_t n, in char* format, ...);
    int  vsnprintf(char* s, size_t n, in char* format, va_list arg);
}
else
{
    static assert( false, "Unsupported platform" );
}

void perror(in char* s);

version (DigitalMars) version (Win32)
{
    import core.sys.windows.windows;

    enum
    {
        FHND_APPEND     = 0x04,
        FHND_DEVICE     = 0x08,
        FHND_TEXT       = 0x10,
        FHND_BYTE       = 0x20,
        FHND_WCHAR      = 0x40,
    }

    private enum _MAX_SEMAPHORES = 10 + _NFILE;
    private enum _semIO = 3;

    private extern __gshared short _iSemLockCtrs[_MAX_SEMAPHORES];
    private extern __gshared int _iSemThreadIds[_MAX_SEMAPHORES];
    private extern __gshared int _iSemNestCount[_MAX_SEMAPHORES];
    private extern __gshared HANDLE[_NFILE] _osfhnd;
    private extern __gshared ubyte[_NFILE] __fhnd_info;

    private void _WaitSemaphore(int iSemaphore);
    private void _ReleaseSemaphore(int iSemaphore);

    // this is copied from semlock.h in DMC's runtime.
    private void LockSemaphore(uint num)
    {
        asm
        {
            mov EDX, num;
            lock;
            inc _iSemLockCtrs[EDX * 2];
            jz lsDone;
            push EDX;
            call _WaitSemaphore;
            add ESP, 4;
        }

    lsDone: {}
    }

    // this is copied from semlock.h in DMC's runtime.
    private void UnlockSemaphore(uint num)
    {
        asm
        {
            mov EDX, num;
            lock;
            dec _iSemLockCtrs[EDX * 2];
            js usDone;
            push EDX;
            call _ReleaseSemaphore;
            add ESP, 4;
        }

    usDone: {}
    }

    // This converts a HANDLE to a file descriptor in DMC's runtime
    int _handleToFD(HANDLE h, int flags)
    {
        LockSemaphore(_semIO);
        scope(exit) UnlockSemaphore(_semIO);

        foreach (fd; 0 .. _NFILE)
        {
            if (!_osfhnd[fd])
            {
                _osfhnd[fd] = h;
                __fhnd_info[fd] = cast(ubyte)flags;
                return fd;
            }
        }

        return -1;
    }

    HANDLE _fdToHandle(int fd)
    {
        // no semaphore is required, once inserted, a file descriptor
        // doesn't change.
        if (fd < 0 || fd >= _NFILE)
            return null;

        return _osfhnd[fd];
    }

    enum
    {
        O_RDONLY = 0x000,
        O_WRONLY = 0x001,
        O_RDWR   = 0x002,
        O_APPEND = 0x008,
        O_CREAT  = 0x100,
        O_TRUNC  = 0x200,
        O_EXCL   = 0x400,
    }

    enum
    {
        S_IREAD = 0x0100,
        S_IWRITE = 0x0080,
    }

    enum
    {
        STDIN_FILENO  = 0,
        STDOUT_FILENO = 1,
        STDERR_FILENO = 2,
    }

    int open(const(char)* filename, int flags, ...);
    int close(int fd);
    FILE *fdopen(int fd, const(char)* flags);
}
