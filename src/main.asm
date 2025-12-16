org 0x7C00  ; Direct the assembler to calculate memory offsets starting at 0x7C00
bits 16     ; Direct the assembler to emit 16 bit code


%define ENDL 0x0D, 0x0A


start:
    jmp main


;   
; Prints a string to the screen.    
; Params:
;   - ds:si points to string
puts:
    ; save registers we will modify
    push si 
    push ax

.loop:
    lodsb           ; Loads next character into AL
    or al, al       ; Verify if next character is null?
    jz .done 

    mov ah, 0x0e    ; BIOS teletype output
    mov bh, 0
    int 0x10

    jmp .loop

.done:
    pop ax
    pop si 
    ret


main:
    ; Setup data segments
    mov ax, 0       ; Can't write to ds/es directly
    mov ds, ax
    mov es, ax

    ; Setup stack
    mov ss, ax
    mov sp, 0x7C00  ; Stack grows downward from where we are loaded in memory

    ; print message
    mov si, msg_hello
    call puts

    hlt             ; Stops CPU execution

.halt:
    jmp .halt       ; If the CPU starts again, we will halt it


msg_hello:
    db 'Hello world!', 0


times 510-($-$$) db 0   ; Pad boot sector to 510 bytes
dw 0xAA55               ; Boot signature

