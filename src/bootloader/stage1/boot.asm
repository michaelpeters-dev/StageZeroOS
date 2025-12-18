org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A        ; CRLF for BIOS teletype output


;
; =========================
; FAT12 BOOT SECTOR HEADER
; =========================
;

jmp short start               ; jump over BPB
nop                           ; required padding

bdb_oem:                    db 'MSWIN4.1'           ; OEM identifier (8 bytes)
bdb_bytes_per_sector:       dw 512                  ; bytes per sector (always 512)
bdb_sectors_per_cluster:    db 1                    ; sectors per cluster
bdb_reserved_sectors:       dw 1                    ; boot sector count
bdb_fat_count:              db 2                    ; number of FATs
bdb_dir_entries_count:      dw 0E0h                 ; root directory entries (224)
bdb_total_sectors:          dw 2880                 ; total sectors (1.44MB floppy)
bdb_media_descriptor_type:  db 0F0h                 ; 3.5" floppy
bdb_sectors_per_fat:        dw 9                    ; sectors per FAT
bdb_sectors_per_track:      dw 18                   ; sectors per track
bdb_heads:                  dw 2                    ; number of heads
bdb_hidden_sectors:         dd 0                    ; unused for floppy
bdb_large_sector_count:     dd 0                    ; unused for floppy

;
; Extended Boot Record
;
ebr_drive_number:           db 0                    ; BIOS drive number
                            db 0                    ; reserved
ebr_signature:              db 29h                  ; EBR signature
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; volume serial number
ebr_volume_label:           db 'STAGEZERO_OS'        ; volume label (11 bytes)
ebr_system_id:              db 'FAT12   '           ; filesystem type


;
; =========================
; BOOT CODE
; =========================
;

start:
    ; initialize segment registers
    mov ax, 0
    mov ds, ax
    mov es, ax
    
    ; initialize stack
    mov ss, ax
    mov sp, 0x7C00            ; stack grows down from bootloader

    ; some BIOSes start execution at 07C0:0000
    ; force CS = 0000
    push es
    push word .after
    retf

.after:

    ; save boot drive number
    mov [ebr_drive_number], dl

    ; print loading message
    mov si, msg_loading
    call puts

    ; query drive geometry from BIOS
    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    ; extract sectors per track
    and cl, 0x3F
    xor ch, ch
    mov [bdb_sectors_per_track], cx

    ; extract head count
    inc dh
    mov [bdb_heads], dh

    ; compute LBA of root directory
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx
    add ax, [bdb_reserved_sectors]
    push ax

    ; compute root directory size in sectors
    mov ax, [bdb_dir_entries_count]
    shl ax, 5                 ; entries * 32 bytes
    xor dx, dx
    div word [bdb_bytes_per_sector]

    test dx, dx
    jz .root_dir_after
    inc ax                    ; round up if partial sector

.root_dir_after:

    ; read root directory into buffer
    mov cl, al
    pop ax
    mov dl, [ebr_drive_number]
    mov bx, buffer
    call disk_read

    ; search for STAGE2.BIN entry
    xor bx, bx
    mov di, buffer

.search_kernel:
    mov si, file_stage2_bin
    mov cx, 11
    push di
    repe cmpsb
    pop di
    je .found_kernel

    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_kernel

    ; file not found
    jmp kernel_not_found_error

.found_kernel:

    ; extract first cluster number
    mov ax, [di + 26]
    mov [stage2_cluster], ax

    ; load FAT into buffer
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    ; set ES:BX to kernel load address
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:
    
    ; read current cluster
    mov ax, [stage2_cluster]
    add ax, 31                ; hardcoded data region LBA
    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    ; advance destination pointer
    add bx, [bdb_bytes_per_sector]

    ; compute FAT12 entry offset
    mov ax, [stage2_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx

    mov si, buffer
    add si, ax
    mov ax, [ds:si]

    ; handle odd/even FAT12 entries
    or dx, dx
    jz .even

.odd:
    shr ax, 4
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF

.next_cluster_after:
    cmp ax, 0x0FF8            ; end of cluster chain?
    jae .read_finish

    mov [stage2_cluster], ax
    jmp .load_kernel_loop

.read_finish:
    
    ; jump to loaded kernel
    mov dl, [ebr_drive_number]

    mov ax, KERNEL_LOAD_SEGMENT
    mov ds, ax
    mov es, ax

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    ; should never reach here
    jmp wait_key_and_reboot

    cli
    hlt


;
; =========================
; ERROR HANDLERS
; =========================
;

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_stage2_not_found
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                   ; wait for key
    jmp 0FFFFh:0              ; reboot via BIOS

.halt:
    cli
    hlt


;
; =========================
; BIOS STRING OUTPUT
; =========================
;
; ds:si -> null-terminated string
;

puts:
    push si
    push ax
    push bx

.loop:
    lodsb
    or al, al
    jz .done

    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .loop

.done:
    pop bx
    pop ax
    pop si
    ret


;
; =========================
; DISK ROUTINES
; =========================
;

;
; LBA -> CHS conversion
; ax = LBA
; returns:
;   cx = cylinder/sector
;   dh = head
;
lba_to_chs:
    push ax
    push dx

    xor dx, dx
    div word [bdb_sectors_per_track]

    inc dx
    mov cx, dx

    xor dx, dx
    div word [bdb_heads]

    mov dh, dl
    mov ch, al
    shl ah, 6
    or cl, ah

    pop ax
    mov dl, al
    pop ax
    ret


;
; Read sectors from disk
; ax = LBA
; cl = sector count
; dl = drive
; es:bx = destination
;
disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs
    pop ax

    mov ah, 02h
    mov di, 3                ; retry count

.retry:
    pusha
    stc
    int 13h
    jnc .done

    popa
    call disk_reset

    dec di
    jnz .retry

    jmp floppy_error

.done:
    popa
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret


;
; Reset disk controller
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret


;
; =========================
; DATA
; =========================
;

msg_loading:            db 'Loading...', ENDL, 0
msg_read_failed:        db 'Read from disk failed!', ENDL, 0
msg_stage2_not_found:   db 'STAGE2.BIN file not found!', ENDL, 0
file_stage2_bin:        db 'STAGE2  BIN'
stage2_cluster:         dw 0

KERNEL_LOAD_SEGMENT     equ 0x2000
KERNEL_LOAD_OFFSET      equ 0


;
; Boot sector padding + signature
;
times 510-($-$$) db 0
dw 0AA55h

buffer: