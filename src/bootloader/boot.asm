org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;
; BIOS loads this sector at address 0x7C00
; Execution begins here
;

jmp start
nop

;
; FAT12 BIOS Parameter Block
; Required so BIOS recognizes this as a valid boot disk
;
bdb_oem:                  db 'MSWIN4.1'
bdb_bytes_per_sector:     dw 512
bdb_sectors_per_cluster:  db 1
bdb_reserved_sectors:     dw 1
bdb_fat_count:            db 2
bdb_dir_entries_count:    dw 224
bdb_total_sectors:        dw 2880
bdb_media_descriptor:     db 0xF0
bdb_sectors_per_fat:      dw 9
bdb_sectors_per_track:    dw 18
bdb_heads:                dw 2
bdb_hidden_sectors:       dd 0
bdb_large_sector_count:   dd 0

; Extended boot record
ebr_drive_number:         db 0
ebr_reserved:             db 0
ebr_signature:            db 0x29
ebr_volume_id:            dd 0x12345678
ebr_volume_label:         db 'STAGEZERO'
ebr_system_id:            db 'FAT12   '

;
; Print string pointed to by DS:SI
;
puts:
    push ax
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    pop ax
    ret

start:
    ; Set segment registers to known state
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Print message
    mov si, msg_hello
    call puts

    cli
    hlt

msg_hello:
    db 'Hello from bootloader!', ENDL, 0

times 510-($-$$) db 0
dw 0xAA55

