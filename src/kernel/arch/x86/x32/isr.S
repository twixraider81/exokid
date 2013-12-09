; implemented in idt.d
extern isrHandler

%macro isrException 1 ; interrupt without errorcode
global isrException%1
isrException%1:
	push 0
	push %1
	jmp isrStub
%endmacro


%macro isrExceptionErr 1 ; interrupt with errorcode
global isrException%1
isrException%1:
	push %1
	jmp isrStub
%endmacro


%macro isrIrq 2 ; irq, no exception
global isrIrq%1
isrIrq%1:
	push 0
	push %2
	jmp isrStub
%endmacro


global isrIpiPanic ; panic ipi
isrIpiPanic:
	push 0
	push 0xFB
	jmp isrStub


global isrIpiTlb ; tlb shootdown ipi
isrIpiTlb:
	push 0
	push 0xFC
	jmp isrStub


global isrLapicTimer ; lvt timer
isrLapicTimer:
	push 0
	push 0xFD
	jmp isrStub


global isrLapicError ; lvt error
isrLapicError:
	push 0
	push 0xFE
	jmp isrStub


global isrLapicSpurious ; spurious
isrLapicSpurious:
	push 0
	push 0xFF
	jmp isrStub


isrStub:
	; save registers on stack
	push eax
	push ebx
	push ecx
	push edx
	push esi
	push edi
	push ebp

	mov ax, ds
	push eax

	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax

	mov edi, esp

	; call exception handler
	call isrHandler

	pop eax
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax

	; restore registers
	pop ebp
	pop edi
	pop esi
	pop edx
	pop ecx
	pop ebx
	pop eax
	add esp, 16

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
