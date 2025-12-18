bits 16

section _ENTRY class=CODE        ; entry code section, placed first in binary

extern _cstart_                 ; C runtime entry point
global entry                    ; linker-visible entry symbol

entry:
    cli                         ; disable interrupts during setup

    ; setup stack
    mov ax, ds                  ; use current data segment
    mov ss, ax                  ; stack segment = data segment
    mov sp, 0                   ; stack starts at top of segment
    mov bp, sp                  ; initialize base pointer

    sti                         ; re-enable interrupts

    ; pass boot drive number to C code
    ; BIOS provides drive number in DL
    xor dh, dh                  ; clear high byte
    push dx                     ; push drive number as argument
    call _cstart_               ; jump to C runtime

    ; should never return here
    cli                         ; disable interrupts
    hlt                         ; halt CPU