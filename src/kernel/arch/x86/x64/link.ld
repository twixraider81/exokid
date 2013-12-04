OUTPUT_FORMAT(elf64-x86-64)
ENTRY(kernel_entry)

PAGE_SIZE	= 0x1000;
KERNEL_VMA	= 0xffffffff80000000;

SECTIONS
{
	. = 0x100000;
	_kernelLMA = .;

	_start = . + KERNEL_VMA;

	.init :
	{
		*(.initl)
	}

	. += KERNEL_VMA;
	_kernelVMA = .;

	.text ALIGN(PAGE_SIZE) : AT(ADDR(.text) - KERNEL_VMA)
	{
		*(.inith)
		*(.text)
		*(.gnu.linkonce.t*)
	}

	.data ALIGN(PAGE_SIZE) : AT(ADDR(.data) - KERNEL_VMA)
	{
		*(.data)
		*(.gnu.linkonce.d*)
	}

	.rodata ALIGN(PAGE_SIZE) : AT(ADDR(.rodata) - KERNEL_VMA)
	{
		*(.rodata)
		*(.rodata.*)
	}

	_tlsstart = .;
	.tdata ALIGN(PAGE_SIZE) : AT(ADDR(.tdata) - KERNEL_VMA)
	{
		*(.tdata .tdata.*)
	}

	.tbss ALIGN(PAGE_SIZE) : AT(ADDR(.tbss) - KERNEL_VMA)
	{
		*(.tbss .tbss.*)  
		*(.tcommon)      
	} 
	_tlsend = . ;

	.bss ALIGN(PAGE_SIZE) : AT(ADDR(.bss) - KERNEL_VMA)
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