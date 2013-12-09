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
       mov esp, STACK_SIZE+stack

       push eax
       push ebx

       call kmain

cpuhalt:
       hlt
       jmp cpuhalt

; memory reserved for the kernel's stack
section .bss
align 16
stack:
	resb STACK_SIZE
