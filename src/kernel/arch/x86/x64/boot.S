; http://wiki.osdev.org/64-bit_Higher_Half_Kernel_with_GRUB_2
bits 32

; kernel start routine
extern kmain
; linker provided externals
extern _start
extern _end

PAGE_SIZE		equ 0x1000
STACK_SIZE		equ 0x4000
KERNEL_VMA		equ 0xffffffff80000000

; paging structures
PAGE_TABLES		equ 0x200
PAGE_PRESENT	equ 0x1
PAGE_WRITABLE	equ 0x2
PAGE_USER		equ 0x4
PAGE_BIG      	equ 0x80
PAGE_NEXEC		equ 0x8000000000000000

; multiboot constants
MULTIBOOT_MAGIC	equ 0xe85250d6 ; multiboot2

; multiboot2 header
section .initl
align 8
header:
	dd MULTIBOOT_MAGIC
	dd 0 ; x86
	dd (header_end - header)
	dd (0 - MULTIBOOT_MAGIC - 0 - (header_end - header)) & 0xFFFFFFFF

	tag_info_start:
		dw 1 ; info tag
		dw 0
		dd (tag_info_end - tag_info_start)
		dd 3 ; module info
		dd 6 ; memory map
	tag_info_end:

	tag_align_start:
		dw 6 ; alignment tag
		dw 0
		dd (tag_align_end - tag_align_start)
	tag_align_end:

	tag_term_start:
		dw 0 ; terminator tag
		dw 0
		dd (tag_term_end - tag_term_start)
	tag_term_end:
header_end:


; initial paging structures
align PAGE_SIZE
global pml4
pml4:
	dq (pml3l + PAGE_PRESENT + PAGE_WRITABLE)
	times (PAGE_TABLES - 4) dq 0
	dq (identity_pml3 + PAGE_PRESENT + PAGE_WRITABLE)
	dq (pml4 + PAGE_PRESENT + PAGE_WRITABLE + PAGE_NEXEC)
	dq (pml3h + PAGE_PRESENT + PAGE_WRITABLE)

pml3l:
	dq (pml2 + PAGE_PRESENT + PAGE_WRITABLE)
	dq 0
	times (PAGE_TABLES - 2) dq 0

pml3h:
	times (PAGE_TABLES - 2) dq 0
	dq (pml2 + PAGE_PRESENT + PAGE_WRITABLE)
	dq 0

pml2:
	dq (0x0 + PAGE_PRESENT + PAGE_WRITABLE + PAGE_BIG)
	times (PAGE_TABLES - 1) dq 0

identity_pml3:
	times (PAGE_TABLES - 5) dq 0
	dq (pmm_stack_pml2 + PAGE_PRESENT + PAGE_WRITABLE)
	dq (identity_pml2a + PAGE_PRESENT + PAGE_WRITABLE)
	dq (identity_pml2b + PAGE_PRESENT + PAGE_WRITABLE)
	dq (identity_pml2c + PAGE_PRESENT + PAGE_WRITABLE)
	dq (identity_pml2d + PAGE_PRESENT + PAGE_WRITABLE)

pmm_stack_pml2:
	times (PAGE_TABLES - 1) dq 0
	dq (pmm_stack_pml1 + PAGE_PRESENT + PAGE_WRITABLE)

pmm_stack_pml1:
	times PAGE_TABLES dq 0

identity_pml2a:
	%assign pg 0
	%rep PAGE_TABLES
		dq (pg + PAGE_PRESENT + PAGE_WRITABLE + PAGE_BIG + PAGE_NEXEC)
		%assign pg pg+PAGE_SIZE*PAGE_TABLES
	%endrep

identity_pml2b:
	%rep PAGE_TABLES
		dq (pg + PAGE_PRESENT + PAGE_WRITABLE + PAGE_BIG + PAGE_NEXEC)
		%assign pg pg+PAGE_SIZE*PAGE_TABLES
	%endrep

identity_pml2c:
	%rep PAGE_TABLES
		dq (pg + PAGE_PRESENT + PAGE_WRITABLE + PAGE_BIG + PAGE_NEXEC)
		%assign pg pg+PAGE_SIZE*PAGE_TABLES
	%endrep

identity_pml2d:
	%rep PAGE_TABLES
		dq (pg + PAGE_PRESENT + PAGE_WRITABLE + PAGE_BIG + PAGE_NEXEC)
		%assign pg pg+PAGE_SIZE*PAGE_TABLES
	%endrep



; the global descriptor table
gdt:
	; null selector
    dq 0
	; cs selector
    dq 0x00AF98000000FFFF
	; ds selector
    dq 0x00CF92000000FFFF
gdt_end:
	dq 0 ; some extra padding so the gdtr is 16-byte aligned
gdtr:
	dw gdt_end - gdt - 1
	dq gdt


; the entry point of the kernel executable
global kernel_entry
kernel_entry:
	; move the info GRUB passes us into the registers used for the main() call
	; later on
	mov edi, eax
	mov esi, ebx

	; enable PAE and PSE
	mov eax, cr4
	or eax, (0x20 + 0x10)
	mov cr4, eax

	; enable long mode and the NX bit
	mov ecx, 0xC0000080
	rdmsr
	or eax, (0x100 + 0x800)
	wrmsr

	; set cr3 to a pointer to pml4
	mov eax, pml4
	mov cr3, eax

	; enable paging
	mov eax, cr0
	or eax, 0x80000000
	mov cr0, eax

	; leave compatibility mode
	lgdt [gdtr]
	mov ax, 0x10
	mov ss, ax
	mov ax, 0x0
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	jmp 0x08:.trampoline

; some 64-bit code in the lower half used to jump to the higher half
bits 64
.trampoline:
	; enter the higher half
	mov rax, qword .next
	jmp rax

; the higher-half code
section .inith
.next:
	; re-load the GDTR with a virtual base address
	mov rax, [gdtr + 2]
	mov rbx, KERNEL_VMA
	add rax, rbx
	mov [gdtr + 2], rax
	mov rax, gdtr + KERNEL_VMA
	lgdt [rax]

	; map the rest of the kernel into virtual memory
	mov rax, _start - KERNEL_VMA      ; first page number
	shr rax, 12 + 9
	mov rbx, _end - KERNEL_VMA        ; last page number
	shr rbx, 12 + 9
	mov rcx, pml2 + KERNEL_VMA   ; pointer into pml2 table
	.map_page:

    ; calculate the value of the page table entry
    mov rdx, rax
    shl rdx, 12 + 9
    mov r8, rdx
    mov r9, KERNEL_VMA
    add r8, r9
    or rdx, PAGE_PRESENT + PAGE_WRITABLE + PAGE_BIG

    ; write the page table entry
    mov [rcx], rdx
    invlpg [r8]

    ; increment pml2 pointer
    add rcx, 8

    ; check if we should terminate the loop
    cmp rax, rbx
    je .map_page_end

    ; increment the counter and map the next page
    inc rax
    jmp .map_page
	.map_page_end:

	; set up the new stack (multiboot2 spec says the stack pointer could be
	; anything - even pointing to invalid memory)
	mov rbp, 0
	mov rsp, qword stack + STACK_SIZE

	; unmap the identity-mapped memory
	mov qword [pml4], 0x0

	; invalidate the TLB cache for the identity-mapped memory
	invlpg [0x0]

	; clear the RFLAGS register
	push 0x0
	popf

	; call the kernel
	; - the arguments were moved into EDI and ESI at the start
	; - the DF has been reset by the code above - no CLD is required
	call kmain

 
; memory reserved for the kernel's stack
section .bss
align 16
stack:
	resb STACK_SIZE