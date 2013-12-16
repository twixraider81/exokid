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
.extern kmain
.global kernel_entry

.set PAGE_SIZE, 0x1000
.set STACK_SIZE, 0x4000

.set MAGIC, 0x1badb002
.set FLAGS, 0x0
.set CHECKSUM, -(MAGIC + FLAGS)

.section .multiboot
.align 4
	.long MAGIC
	.long FLAGS
	.long CHECKSUM


.section .bootstack
stack_bottom:
.skip STACK_SIZE
stack_top:

.section .text
kernel_entry:
	cli
	movl $stack_top, %esp

	push %ebx
	push %eax

	movl %cr0, %ecx
	btr $2, %ecx
	btr $1, %ecx
	movl %ecx, %cr0

	movl %cr4, %ecx
	btr $9, %ecx
	btr $10, %ecx
	movl %ecx, %cr4

	call kmain

cpuhalt:
	hlt
	jmp cpuhalt
