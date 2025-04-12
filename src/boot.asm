[org 0x7C00]
[bits 16]

entry:
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Switch to protected mode
    cli                     ; Disable interrupts
    call EnableA20          ; Enable A20 gate
    call LoadGDT            ; Load GDT

    ; Set protection enable flag in cr0
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; Far jump into protected mode
    jmp dword 08h:.pmode

.pmode:
    ;  We are now in protected mode
    [bits 32]

    ; Setup registers
    mov ax, 0x10
    mov ds, ax
    mov ss, ax

    ; Print hello world
    mov esi, HelloMsg
    mov edi, ScreenBuffer
    cld

.ploop:
    lodsb
    or al, al
    jz .pdone

    mov [edi], al
    inc edi

    mov [edi], byte 0x1F
    inc edi
    jmp .ploop

.pdone:
    ; Go back to real mode
    jmp word 18h:.pmode16 ; Jump to 16 bit protected mode segment

.pmode16:
    [bits 16]

    ; Disable protected mode in bit of cr0
    mov eax, cr0
    and al, ~1
    mov cr0, eax

    ; Jump to real mode
    jmp word 0h:.rmode

.rmode:
    ; Setup registers
    mov ax, 0
    mov ds, ax
    mov ss, ax

    ; Enablr interrupts
    sti

    ; Print hello world using itn 10h
    mov si, RHelloMsg

.rloop:
    lodsb
    or al, al
    jz .rdone

    mov ah, 0Eh
    mov bh, 0
    int 10h
    jmp .rloop

.rdone:

.halt:
    jmp .halt

LoadGDT:
    [bits 16]
    lgdt [g_GDTDesc]
    ret

EnableA20:
    [bits 16]
    ; Disable keyboard
    call A20WaitInput
    mov al, KBD_CONTROLLER_DISABLE_KEYBOARD
    out KBD_CONTROLLER_COMMAND_PORT, al

    ; Read control output port (i.e. flush output buffer)
    call A20WaitInput
    mov al, KBD_CONTROLLER_READ_CTRL_OUTPUT_PORT
    out KBD_CONTROLLER_COMMAND_PORT, al

    call A20WaitOutput
    in al, KBD_CONTROLLER_DATA_PORT
    push eax

    ; Wirte control output port
    call A20WaitInput
    mov al, KBD_CONTROLLER_WRITE_CTRL_OUTPUT_PORT
    out KBD_CONTROLLER_COMMAND_PORT, al

    call A20WaitInput
    pop eax
    or al, 2                ; Bit 2 = A20 bit
    out KBD_CONTROLLER_DATA_PORT, al

    ; Enable keyboard
    call A20WaitInput
    mov al, KBD_CONTROLLER_ENABLE_KEYBOARD
    out KBD_CONTROLLER_COMMAND_PORT, al

    call A20WaitInput
    ret

A20WaitOutput:
    [bits 16]
    ; Wait until status bit 2 (input buffer) is 0
    in al, KBD_CONTROLLER_COMMAND_PORT
    test al, 2
    jnz A20WaitInput
    ret

A20WaitInput:
    [bits 16]
    ; Wait until status bit 1 (input buffer) is 1 so it can be read
    in al, KBD_CONTROLLER_COMMAND_PORT
    test al, 1
    jz A20WaitOutput
    ret

KBD_CONTROLLER_DATA_PORT                equ 0x60
KBD_CONTROLLER_COMMAND_PORT             equ 0x64
KBD_CONTROLLER_DISABLE_KEYBOARD         equ 0xAD
KBD_CONTROLLER_ENABLE_KEYBOARD          equ 0xAE
KBD_CONTROLLER_READ_CTRL_OUTPUT_PORT    equ 0xD0
KBD_CONTROLLER_WRITE_CTRL_OUTPUT_PORT   equ 0xD1

ScreenBuffer                            equ 0xB8000

g_GDT:      ; NULL descriptor
            dq 0

            ; 32 bit code segment
            dw 0FFFFh                   ; Limit (bits 0-15)
            dw 0                        ; Base (bits 0-15)
            db 0                        ; Base (bits 16-23)
            db 10011010b                ; Access (present, ring 0, code segment, executable, direction 0, writable)
            db 11001111b                ; Granularity (4k page, 32-bit mode) + limit (bits 16-19)
            db 0                        ; Base high

            ; 32 bit data segment
            dw 0FFFFh                   ; Limit (bits 0-15)
            dw 0                        ; Base (bits 0-15)
            db 0                        ; Base (bits 16-23)
            db 10010010b                ; Access (present, ring 0, data segment, executable, direction 0, writable)
            db 11001111b                ; Granularity (4k page, 32-bit mode) + limit (bits 16-19)
            db 0                        ; Base high

            ; 16 bit code segment
            dw 0FFFFh                   ; Limit (bits 0-15)
            dw 0                        ; Base (bits 0-15)
            db 0                        ; Base (bits 16-23)
            db 10011010b                ; Access (present, ring 0, code segment, executable, direction 0, writable)
            db 00001111b                ; Granularity (1b page, 16-bit mode) + limit (bits 16-19)
            db 0                        ; Base high

            ; 16 bit data segment
            dw 0FFFFh                   ; Limit (bits 0-15)
            dw 0                        ; Base (bits 0-15)
            db 0                        ; Base (bits 16-23)
            db 10010010b                ; Access (present, ring 0, data segment, executable, direction 0, writable)
            db 00001111b                ; Granularity (1b page, 16-bit mode) + limit (bits 16-19)
            db 0                        ; Base high

g_GDTDesc:  dw g_GDTDesc - g_GDT - 1    ; Limit - size of GDT
            dd g_GDT                    ; Address of GDT
HelloMsg:   db 'Hello world from protected mode!', 0
RHelloMsg:  db 'Hello world from real mode!', 0

times 510 - ($ - $$) db 0
dw 0AA55h