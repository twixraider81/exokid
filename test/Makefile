DIR := $(shell pwd)/
SRCFILES := $(shell find $(DIR) -name '*.[c]')
OBJFILES := $(addsuffix .o,$(basename $(SRCFILES)))
PROJFILES := $(basename $(SRCFILES))

CC		:= $(shell which gcc)
CCFLAGS	:= -c -m64
LD		:= $(CC)

all: $(PROJFILES)

clean:
	@$(RM) $(OBJFILES)
	@$(RM) $(PROJFILES)

%: %.o
	$(LD) -v $^ -o $@

%.o: %.c
	$(CC) $(CCFLAGS) $^
	
.PHONY: all clean