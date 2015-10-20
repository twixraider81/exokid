/**
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
.code32

.extern kmain
.extern _start
.extern _end

.equ MULTIBOOT2_HEADER_MAGIC,		0xe85250d6
.equ MULTIBOOT2_HEADER_ARCH_I386,	0
.equ MULTIBOOT2_INFO_REQUIRED,		0
.equ MULTIBOOT2_TAG_TERMINATOR,		0
.equ MULTIBOOT2_TAG_INFO_REQ,		1
.equ MULTIBOOT2_TAG_MODULE,			3
.equ MULTIBOOT2_TAG_ENTRY_ADDRESS,	3
.equ MULTIBOOT2_TAG_MEMMAP,			6
.equ MULTIBOOT2_TAG_MODULE_ALIGN,	6

.equ PAGE_SIZE,		0x1000
.equ STACK_SIZE,	0x4000

// multiboot2 header
.section .multiboot2, "ax"
.align 8
multiboot2_header:
	.long MULTIBOOT2_HEADER_MAGIC
	.long MULTIBOOT2_HEADER_ARCH_I386
	.long multiboot2_header_end - multiboot2_header
	.long -(MULTIBOOT2_HEADER_MAGIC + MULTIBOOT2_HEADER_ARCH_I386 + (multiboot2_header_end - multiboot2_header))

	tag_info_start:
		.word MULTIBOOT2_TAG_INFO_REQ
		.word MULTIBOOT2_INFO_REQUIRED
		.long (tag_info_end - tag_info_start)
		.long MULTIBOOT2_TAG_MODULE
		.long MULTIBOOT2_TAG_MODULE_ALIGN
	tag_info_end:

	tag_align_start:
		.word MULTIBOOT2_TAG_MODULE_ALIGN
		.word MULTIBOOT2_INFO_REQUIRED
		.long (tag_align_end - tag_align_start)
	tag_align_end:

	tag_term_start:
		.word MULTIBOOT2_TAG_TERMINATOR
		.word MULTIBOOT2_INFO_REQUIRED
		.long ( tag_term_end - tag_term_start )
	tag_term_end:

multiboot2_header_end:

// initial gdt
gdt:
	# null descriptor
	gdt_null:
	.word 0
	.word 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	# null descriptor
	gdt_unused:
	.word 0
	.word 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	# code descriptor
	gdt_code:
	.word 0xffff
	.word 0
	.byte 0
	.byte 0x9a
	.byte 0xaf
	.byte 0
	# data descriptor
	gdt_data:
	.word 0xffff
	.word 0
	.byte 0
	.byte 0x92
	.byte 0x8f
	.byte 0
	gdt_pointer:
	.word gdt_pointer - gdt - 1
	.long gdt
	.long 0
gdt_end:


// the entry point of the kernel executable
.global kernel_entry
kernel_entry:
xchg %BX, %BX
	cli
	cld
	// move the multiboot info grub passes us into registers used for the main() call
	mov %eax, %edi
	mov %ebx, %esi

	// enable PAE and PSE
	mov %cr4, %eax
	orl (0x20 + 0x10), %eax
	mov %eax, %cr4

	// enable long mode and the nx bit
	mov $0xC0000080, %ecx
	rdmsr
	or (0x100 + 0x800), %eax
	wrmsr

	// enable paging and enter long mode
	mov %cr0, %eax
	orl $0x80000000, %eax
	mov %eax, %cr0

	// load initial gdt
	#lgdtl gdt_pointer

	mov $0x10, %ax
	mov %ax, %ss
	mov $0x0, %ax
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %fs
	mov %ax, %gs

	ljmp $0x10, $trampoline

// 64-bit code in the lower half used to jump to the higher half
.code64
trampoline:
	// enter the higher half
	mov .next, %rax
	jmp *%rax

// finally the higher-half code
.section .kinit
.next:


	// clear the RFLAGS register
	push $0x0
	popf

	// call kernel
	call kmain

	cli

halt:
	hlt
	jmp halt

 
// memory reserved for the kernel's stack
.section .bss
.align 16
stack:
	.space STACK_SIZE
