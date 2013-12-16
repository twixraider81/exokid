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
.set STACK_SIZE,		0x4000
.set MULTIBOOT_MAGIC,	0x1badb002
.set MULTIBOOT_FLAGS,	0x00010003

.section multiboot
.align 4
multiboot_header:
	.int MULTIBOOT_MAGIC
	.int MULTIBOOT_FLAGS
	.int -(MULTIBOOT_MAGIC + MULTIBOOT_FLAGS)
	.int multiboot_header

.section .text
.extern kmain
.global kernel_entry
kernel_entry:
	cli

	mov $stack, %esp
	mov %esp, %ebp

	push %ebx
	push %eax

	mov %cr0, %ecx
	btr $2, %ecx
	btr $1, %ecx
	mov %ecx, %cr0

	mov %cr4, %ecx
	btr $9, %ecx
	btr $10, %ecx
	mov %ecx, %cr4

	call kmain

halt:
	cli
	hlt
	jmp halt

.section .bss
.space STACK_SIZE
stack:
