#!/bin/sh
# Run the OS using QEMU (simpler than Bochs)

qemu-system-i386 -fda build/main_floppy.img

