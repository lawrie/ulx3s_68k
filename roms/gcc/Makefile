# apt-get install gcc-m68k-linux-gnu
GCC     = m68k-linux-gnu-gcc
GCC_OPT = -march=68000 -Os -fomit-frame-pointer -ffreestanding -nostdlib -nostartfiles
LD      = m68k-linux-gnu-ld
OBJCOPY = m68k-linux-gnu-objcopy
OBJDUMP = m68k-linux-gnu-objdump

PROJECT = fill

all: $(PROJECT).mem # $(PROJECT).dis

erase_files = $(PROJECT).o $(PROJECT).bin $(PROJECT).mem *~

$(PROJECT).bin: $(PROJECT).c
	$(GCC) $(GCC_OPT) $< -Wl,-Tlinker_script.ld -o $@

#$(PROJECT).bin: $(PROJECT).o
#	$(LD) -T linker_script.ld $< -o $@

$(PROJECT).mem: $(PROJECT).bin
	hexdump -v -e '2/1 "%02X" "\n"' $< > $@

$(PROJECT).dis: $(PROJECT).o
	$(OBJDUMP) -d $<

clean:
	rm -f $(erase_files)
