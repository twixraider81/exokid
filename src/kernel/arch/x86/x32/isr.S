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
.extern isrHandler

.macro isrException exception
.global isrException\exception
isrException\exception:
	push $0
	push $\exception
	jmp isrStub
.endm


.macro isrExceptionErr exception
.global isrException\exception
isrException\exception:
	push $\exception
	jmp isrStub
.endm


.macro isrIrq irq exception
.global isrIrq\irq
isrIrq\irq:
	push $0
	push $\exception
	jmp isrStub
.endm


.global isrIpiPanic
isrIpiPanic:
	push $0
	push $0xFB
	jmp isrStub


.global isrIpiTlb
isrIpiTlb:
	push $0
	push $0xFC
	jmp isrStub


.global isrLapicTimer
isrLapicTimer:
	push $0
	push $0xFD
	jmp isrStub


.global isrLapicError
isrLapicError:
	push $0
	push $0xFE
	jmp isrStub


.global isrLapicSpurious
isrLapicSpurious:
	push $0
	push $0xFF
	jmp isrStub


isrStub:
	push %eax
	push %ebx
	push %ecx
	push %edx
	push %esi
	push %edi
	push %ebp

	mov %ds, %ax
	push %eax

	mov $0x10, %ax
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %fs
	mov %ax, %gs
	mov %ax, %ss

	movl %esp, %edi

	call isrHandler

	pop %eax
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %fs
	mov %ax, %gs

	pop %ebp
	pop %edi
	pop %esi
	pop %edx
	pop %ecx
	pop %ebx
	pop %eax
	add $16, %esp

	iret


isrException		0
isrException		1
isrException		2
isrException		3
isrException		4
isrException		5
isrException		6
isrException		7
isrExceptionErr		8
isrException		9
isrExceptionErr		10
isrExceptionErr		11
isrExceptionErr		12
isrExceptionErr		13
isrExceptionErr		14
isrException		15
isrException		16
isrExceptionErr		17
isrException		18
isrException		19
isrException		20
isrException		21
isrException		22
isrException		23
isrException		24
isrException		25
isrException		26
isrException		27
isrException		28
isrException		29
isrException		30
isrException		31
isrIrq				0,  32
isrIrq				1,  33
isrIrq				2,  34
isrIrq				3,  35
isrIrq				4,  36
isrIrq				5,  37
isrIrq				6,  38
isrIrq				7,  39
isrIrq				8,  40
isrIrq				9,  41
isrIrq				10, 42
isrIrq				11, 43
isrIrq				12, 44
isrIrq				13, 45
isrIrq				14, 46
isrIrq				15, 47
isrIrq				16, 48
isrIrq				17, 49
isrIrq				18, 50
isrIrq				19, 51
isrIrq				20, 52
isrIrq				21, 53
isrIrq				22, 54
isrIrq				23, 55
