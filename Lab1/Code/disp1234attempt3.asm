        ORG 0000h           ; Reset vector
        AJMP MainProg       ; Jump to main program

        ORG 000Bh           ; Timer0 (TF0) interrupt vector (must be ≤8 bytes)
        AJMP ISRTF0         ; Jump to Timer0 ISR

        ORG 0100h           ; Start of main program
MainProg:
        MOV SP, #35h        ; Set stack pointer
        MOV TMOD, #11h      ; Configure Timer0 and Timer1 in mode 1 (16-bit mode)
        ; Set Timer0 initial value (not critical, since we reload in ISR)
        MOV TH0, #0ECh      
        MOV TL0, #078h      
        SETB TR0            ; Start Timer0
        SETB EA             ; Enable global interrupts
        SETB ET0            ; Enable Timer0 interrupt

        ; Initialize digit index variable in internal RAM (using address 30h)
        MOV 30h, #00h       ; 0 => first digit, 1 => second, etc.

WaitLoop:
        NOP
        SJMP WaitLoop       ; Main loop does nothing—display refresh is handled in ISR

;-----------------------------------------------------
; Timer0 ISR: Refresh one 7-seg digit per interrupt every 5ms
;-----------------------------------------------------
ISRTF0:
        PUSH ACC            ; Save registers used in ISR
        PUSH PSW

        ; Reload Timer0 for a 5ms interval.
        ; With a 12MHz clock (1µs per machine cycle), 5000 counts are needed.
        ; Reload value = 65536 - 5000 = 60536 = 0xEC78.
        MOV TH0, #0ECh      ; High byte = 0xEC (236 decimal)
        MOV TL0, #078h      ; Low byte  = 0x78 (120 decimal)

        ; Get current digit index from RAM (at address 30h)
        MOV A, 30h

        ; Select the digit to display based on the digit index:
        CJNE A, #00h, Check1
        ; For index 0: display "1" with demux enable 0x10
        MOV A, #01h
        ORL A, #10h
        SJMP UpdateDigit
Check1:
        CJNE A, #01h, Check2
        ; For index 1: display "2" with demux enable 0x20
        MOV A, #02h
        ORL A, #20h
        SJMP UpdateDigit
Check2:
        CJNE A, #02h, Check3
        ; For index 2: display "3" with demux enable 0x40
        MOV A, #03h
        ORL A, #40h
        SJMP UpdateDigit
Check3:
        ; For index 3: display "4" with demux enable 0x80
        MOV A, #04h
        ORL A, #80h
UpdateDigit:
        MOV P1, A         ; Output the BCD+demux pattern to Port1

        ; Increment digit index and wrap back to 0 after 3
        MOV A, 30h
        INC A
        CJNE A, #04h, NoWrap
        MOV A, #00h       ; Reset index after 4 digits
NoWrap:
        MOV 30h, A

        POP PSW           ; Restore registers
        POP ACC
        RETI              ; Return from interrupt

        END
