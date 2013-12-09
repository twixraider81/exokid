OUTPUT_FORMAT(elf32-i386)
ENTRY(kernel_entry)

PAGE_SIZE	= 0x1000;

SECTIONS
{
    . = 0x100000;

    _kernelLMA = .;
    _start = .;

	.boot :
	{
		*(.multiboot)
	}

    _kernelVMA = .;

	.text ALIGN(PAGE_SIZE) : AT(ADDR(.text))
	{
		*(.inith)
		*(.text)
		*(.gnu.linkonce.t*)
	}

	.data ALIGN(PAGE_SIZE) : AT(ADDR(.data))
	{
		*(.data)
		*(.gnu.linkonce.d*)
	}

	.rodata ALIGN(PAGE_SIZE) : AT(ADDR(.rodata))
	{
		*(.rodata)
		*(.rodata.*)
	}

	_tlsstart = .;
	.tdata ALIGN(PAGE_SIZE) : AT(ADDR(.tdata))
	{
		*(.tdata .tdata.*)
	}

	.tbss ALIGN(PAGE_SIZE) : AT(ADDR(.tbss))
	{
		*(.tbss .tbss.*)  
		*(.tcommon)      
	} 
	_tlsend = . ;

	.bss ALIGN(PAGE_SIZE) : AT(ADDR(.bss))
	{
		*(COMMON)
		*(.bss .bss.*)
		*(.gnu.linkonce.b*)
	}

	_end = .;

	/DISCARD/ :
	{
		*(.ehframe)
		*(.comment)
	}
}