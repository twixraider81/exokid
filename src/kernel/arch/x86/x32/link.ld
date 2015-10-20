ENTRY(kernel_entry)
OUTPUT_FORMAT("elf32-i386")

PAGE_SIZE	= 0x1000;

SECTIONS
{
    . = 0x100000;
    _start = .;
 
    _kernelLMA = .;
    _kernelVMA = .;

    .text :
    {
        *(multiboot)
        *(.text)
    }

    .data ALIGN(PAGE_SIZE) :
    {
        *(.data)
    }

    .rodata ALIGN(PAGE_SIZE) :
    {
        *(.rodata)
    }

	_tlsstart = .;
	.tdata ALIGN(PAGE_SIZE) :
	{
		*(.tdata .tdata.*)
	}

	.tbss ALIGN(PAGE_SIZE) :
	{
		*(.tbss .tbss.*)  
		*(.tcommon)      
	} 
	_tlsend = . ;

	.bss ALIGN(PAGE_SIZE) :
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