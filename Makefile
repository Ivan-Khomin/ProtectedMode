SRC_DIR=src
BUILD_DIR=build
ASM=nasm

.PHONY: floppy_imagerun run debug

floppy_image: $(BUILD_DIR)/pmode.img

$(BUILD_DIR)/pmode.img: $(BUILD_DIR)/boot.bin
	cp $(BUILD_DIR)/boot.bin $(BUILD_DIR)/floppy.img
	truncate -s 1440k $(BUILD_DIR)/floppy.img

$(BUILD_DIR)/boot.bin: $(SRC_DIR)/boot.asm
	$(ASM) -f bin -o $@ $<

clean:
	rm -rf $(BUILD_DIR)/*

run:
	sh run.sh

debug:
	sh debug.sh