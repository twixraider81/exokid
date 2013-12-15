; http://wiki.osdev.org/D_Bare_Bones
bits 32

; kernel start routine
extern kmain
global kernel_entry

PAGE_SIZE		equ 0x1000
STACK_SIZE		equ 0x4000

MAGIC			equ 0x1badb002
FLAGS			equ 0x0
CHECKSUM		equ -(MAGIC + FLAGS)

section .multiboot
align 4
		dd MAGIC
		dd FLAGS
		dd CHECKSUM

section .text
kernel_entry:
		cli
		mov esp, STACK_SIZE+stack

		push ebx
		push eax

		; enable SSE
		mov ecx, cr0
		btr ecx, 2
		bts ecx, 1
		mov cr0, ecx

		mov ecx, cr4
		bts ecx, 9
		bts ecx, 10
		mov cr4, ecx

		call kmain

cpuhalt:
		hlt
		jmp cpuhalt

; memory reserved for the kernel's stack
section .bss
align 32
stack:
		resb STACK_SIZE
