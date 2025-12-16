org 0x0000
bits 16

; kernel entry point
; control jumps here after the bootloader finishes

start:
    ; print a message so we know the kernel was loaded
    mov si, msg
    call puts

.halt:
    ; stop execution
    hlt
    jmp .halt


;
; print string at ds:si using bios teletype
;
puts:
    push ax

.loop:
    lodsb              ; load next character
    or al, al          ; check for null terminator
    jz .done

    mov ah, 0x0E       ; bios teletype output
    int 0x10

    jmp .loop

.done:
    pop ax
    ret


msg:
    db 'Hello from kernel!', 0

