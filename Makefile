TARGET		:= x86_64-pc-elf
#TARGET		:= aarch64-elf
#TARGET		:= i686-pc-elf

QUIET		:= @
DIR			:= $(shell pwd)/
SRCDIR		:= $(DIR)src/
CROSSDIR	:= $(DIR)cross-$(TARGET)/
SUPPORTDIR	:= $(DIR)support/
TMPDIR		:= /tmp/
SRCFILES	:= $(shell find $(SRCDIR) -name '*.[cdS]')
OBJFILES	:= $(addsuffix .o,$(basename $(SRCFILES)))
BACKUP		:= ~/backup/exokid-$(shell date +%Y-%m-%d-%H-%M).tar.bz2

VMA			:= 0xffffffff80000000
PSIZE		:= 0x1000
SSIZE		:= 0x4000

#ASM		:= $(QUIET)$(CROSSDIR)bin/yasm
#ASMFLAGS	:= -f elf64 -m amd64 -g dwarf2 -D STACK_SIZE=$(SSIZE) -D PAGE_SIZE=$(PSIZE) -D KERNEL_VMA=$(VMA) --objfile=
ASM			:= $(QUIET)$(shell which nasm)
ASMFLAGS	:= -felf64 -g -Fdwarf -Werror -Wgnu-elf-extensions -Wfloat-denorm -s -Ox -DSTACK_SIZE=$(SSIZE) -DPAGE_SIZE=$(PSIZE) -DKERNEL_VMA=$(VMA) -o

#DC		:= $(QUIET)$(CROSSDIR)bin/ldc2
#DCFLAGS	:= -nodefaultlib -m64 -code-model=kernel -d-debug -g -c -nodefaultlib -disable-simplify-drtcalls -disable-simplify-libcalls -disable-red-zone -I$(SRCDIR) -I$(SRCDIR)druntime/ -I$(SRCDIR)druntime/rt/ -fthread-model=local-exec -ignore -c -output-o -w -x86-early-ifcvt -float-abi=hard -fatal-assembler-warnings -O2 -enable-asserts -of=
DC		:= $(QUIET)$(CROSSDIR)bin/$(TARGET)-gdc
DCFLAGS	:= -I$(SRCDIR) -I$(SRCDIR)druntime/ -I$(SRCDIR)druntime/rt/ -m64 -nostdinc -nostdlib -fno-bounds-check -fno-emit-moduleinfo -fversion=NoSystem -mcmodel=kernel -mno-red-zone -mno-mmx -mno-sse3 -mno-3dnow -g -fdebug -c -O2 -o 

LD		:= $(QUIET)$(CROSSDIR)bin/$(TARGET)-ld
LDFLAGS	:= -nostdlib --reduce-memory-overheads --error-unresolved-symbols -z defs -z max-page-size=$(PSIZE)

CC		:= $(QUIET)$(CROSSDIR)bin/$(TARGET)-gcc
CCFLAGS	:= -std=c99 -nostdlib -ffreestanding -mcmodel=kernel -mno-red-zone -mno-mmx -mno-sse3 -mno-3dnow -c -o 

OBJDMP	:= $(QUIET)$(CROSSDIR)bin/$(TARGET)-objdump
OBJCOPY	:= $(QUIET)$(CROSSDIR)bin/$(TARGET)-objcopy
NM		:= $(QUIET)$(CROSSDIR)bin/$(TARGET)-nm

BOCHS	:= $(QUIET)$(CROSSDIR)bin/bochs
GDB		:= $(QUIET)$(shell which gdb)

QEMU	:= $(QUIET)$(shell which qemu-system-x86_64)
QEMUFLAGS	:= -no-reboot -no-shutdown -s -S -smp 2 -m 512 -monitor stdio -serial stdio


help:
	$(QUIET)echo "\nPlease use one of the following targets:\n\n- kernel: build kernel\n- clean: remove temporaries\n- kernel.img: builds an image file, bootable with bochs/qemu\n- kernel.sym: symbol tale needed for bochs\n\n- bochs: build everything and fire up bochs (must be present in cross tools dir)\n- qemu: build everything and fire up qemu\n- gdb: fire up gdb and load kernel.bin\n- kdbg: fire up kdbg and load kernel.bin\n- disasm: disassemble via objdump\n\n- backup: create backup archive at $(BACKUP)\n- todo: show FIXME's"

kernel: kernel.bin

kernel.bin: Makefile $(OBJFILES) $(SRCDIR)kernel/arch/x64/link.ld
	$(LD) $(LDFLAGS) -T $(SRCDIR)kernel/arch/x64/link.ld -o $(DIR)kernel.bin $(OBJFILES)

clean:
	$(QUIET)$(RM) $(OBJFILES)
	$(QUIET)$(RM) $(DIR)kernel.bin $(DIR)kernel.img $(DIR)kernel.sym
	$(QUIET)cd test; make clean

%.o: %.d
	@echo $^
	$(DC) $(DCFLAGS)$@ $^

%.o: %.S
	@echo $^
	$(ASM) $(ASMFLAGS)$@ $^

%.o: %.c
	@echo $^
	$(CC) $(CCFLAGS)$@ $^

kernel.img: kernel.bin
	-$(QUIET)umount $(TMPDIR)mnt
	$(QUIET)$(RM) -rf $(DIR)kernel.img
	$(QUIET)xzcat $(SUPPORTDIR)disk.img.xz > $(DIR)kernel.img
	$(QUIET)mkdir -p $(TMPDIR)mnt
	$(QUIET)mount -o loop,offset=32256 $(DIR)kernel.img $(TMPDIR)mnt
	$(QUIET)cp $(DIR)kernel.bin $(TMPDIR)mnt/boot
	$(QUIET)cp $(SUPPORTDIR)grub.cfg $(TMPDIR)mnt/boot/grub
	$(QUIET)chmod 644 $(TMPDIR)mnt/boot/grub/grub.cfg
	$(QUIET)umount $(TMPDIR)mnt
	$(QUIET)rm -rf $(TMPDIR)mnt

kernel.sym: kernel.bin
	$(NM) $(DIR)kernel.bin | grep " T " | awk '{ print $$1" "$$3 }' > $(DIR)kernel.sym

qemu: kernel.img
	$(QEMU) $(QEMUFLAGS) -hda $(DIR)kernel.img

bochs: kernel.img kernel.sym
	-$(QUIET)$(RM) $(TMPDIR)kernel.out
	-$(QUIET)$(RM) $(TMPDIR)bochs.out
	$(QUIET)cp $(DIR)kernel.img $(TMPDIR)
	$(QUIET)cp $(DIR)kernel.sym $(TMPDIR)
	$(BOCHS) -qf $(SUPPORTDIR)bochsrc
	-$(QUIET)$(RM) $(TMPDIR)kernel.img
	-$(QUIET)$(RM) $(TMPDIR)kernel.sym

gdb: kernel.bin
	$(GDB) --tui --eval-command="target remote :1234" $(DIR)kernel.bin

kdbg: kernel.bin
	kdbg -r :1234 $(DIR)kernel.bin

disasm: kernel.bin
	$(OBJDMP) -S $(DIR)kernel.bin | less

backup: clean
	$(QUIET)tar --exclude="cross-*" -cj ./ -f $(BACKUP)

todo:
	$(QUIET)fgrep -Hnr "//FIXME" $(SRCFILES)

.PHONY: all clean kernel qemu bochs gdb kdbg backup todo disasm help