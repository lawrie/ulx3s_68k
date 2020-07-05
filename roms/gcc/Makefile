GCC     = m68k-linux-gnu-gcc
GCC_OPT = -march=68000 -fomit-frame-pointer -ffreestanding -nostdlib -nostartfiles -Os
OBJCOPY = m68k-linux-gnu-objcopy
OBJDUMP = m68k-linux-gnu-objdump

PROJECT = fill

all: $(PROJECT).mem $(PROJECT).dis

erase_files = $(PROJECT).o $(PROJECT).bin $(PROJECT).mem *~

$(PROJECT).o: $(PROJECT).c
	$(GCC) $(GCC_OPT) -c $< -o $@

$(PROJECT).bin: $(PROJECT).o
	$(OBJCOPY) -O binary $< $@

$(PROJECT).mem: $(PROJECT).bin
	hexdump -v -e '2/1 "%02X" "\n"' $< > $@

$(PROJECT).dis: $(PROJECT).o
	$(OBJDUMP) -d $<

clean:
	rm -f $(erase_files)
