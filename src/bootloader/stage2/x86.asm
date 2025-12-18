bits 16

section _TEXT class=CODE

;
; BIOS video teletype output
; int 10h / ah = 0Eh
; args: char, page
;
global _x86_Video_WriteCharTeletype
_x86_Video_WriteCharTeletype:

    push bp             ; setup stack frame
    mov bp, sp

    push bx             ; preserve bx

    ; [bp+4] = character
    ; [bp+6] = page
    mov ah, 0Eh
    mov al, [bp + 4]
    mov bh, [bp + 6]

    int 10h             ; BIOS call

    pop bx              ; restore bx
    mov sp, bp          ; tear down stack frame
    pop bp
    ret