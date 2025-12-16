# Assembler to use
ASM = nasm

SRC_DIR = src
BUILD_DIR = build

.PHONY: all clean always floppy_image kernel bootloader

# Default target
all: floppy_image

#
# Build full floppy disk image
#
floppy_image: $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main_floppy.img: bootloader kernel
	# Create empty 1.44MB floppy image
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880

	# Format image as FAT12 (required by BIOS boot)
	mkfs.fat -F 12 -n "STAGE0" $(BUILD_DIR)/main_floppy.img

	# Write bootloader to first sector
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc

	# Copy kernel into FAT filesystem
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernel.bin "::kernel.bin"

#
# Bootloader
#
bootloader: $(BUILD_DIR)/bootloader.bin

$(BUILD_DIR)/bootloader.bin: always
	$(ASM) $(SRC_DIR)/bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin

#
# Kernel
#
kernel: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: always
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o $(BUILD_DIR)/kernel.bin

#
# Ensure build directory exists
#
always:
	mkdir -p $(BUILD_DIR)

#
# Clean build artifacts
#
clean:
	rm -rf $(BUILD_DIR)/*
