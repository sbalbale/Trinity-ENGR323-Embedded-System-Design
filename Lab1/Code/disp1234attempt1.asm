;----------------------------------------------------------
;  Display “1234” on 4-digit 7-seg using Timer0 ISR @ 5ms
;  8051 @ 12MHz
;
;  P1.0–P1.3 = BCD lines to 7-seg decoder
;  P1.4–P1.5 = which digit is active
;
;  Timer0 mode 1, reload = 0xECC8 → ~5ms overflow
;----------------------------------------------------------

            ORG     0000h
            AJMP    MAIN            ; Reset vector → MAIN

            ORG     000Bh           ; Timer0 overflow vector
            AJMP    TIMER0_ISR

;----------------------------------------------------------------------
;  Data tables in CODE space
;  “Digits” table: BCD for ‘1’, ‘2’, ‘3’, ‘4’
;  “Select” table: which digit to enable (bits for P1.5–P1.4)
;----------------------------------------------------------------------
            ORG     0030h

BCD_TABLE:  DB      1, 2, 3, 4      ; BCD for “1,2,3,4”

; For digit select lines (P1.5–P1.4) we want:
;   digit0 → 00b, digit1 → 01b, digit2 → 10b, digit3 → 11b
; or in decimal: 0,1,2,3
SEL_TABLE:  DB      0, 1, 2, 3


;---------------------------------------------------------------------- 
;  Variable declaration in internal RAM 
;---------------------------------------------------------------------- 
            ORG     20H         ; choose an unused RAM segment
C:          DS      1           ; allocate 1 byte for variable C
;----------------------------------------------------------------------
;  Simple RAM variable for the digit index
;----------------------------------------------------------------------
            ORG     30H         ; start of internal RAM
DigitIndex: DS      1           ; allocate 1 byte in internal RAM

;----------------------------------------------------------------------
;  Main Program
;----------------------------------------------------------------------
            ORG     0040h
MAIN:
            MOV     SP, #60h       ; Set up stack pointer (optional)

            ;--- Configure Timer0 in 16-bit mode (TMOD = 0000_0001) ---
            MOV     TMOD, #01h

            ;--- Load initial counts for 5ms at 12MHz: 0xECC8 ---
            MOV     TH0, #0xEC
            MOV     TL0, #0xC8

            ;--- Enable interrupts ---
            SETB    EA            ; Global interrupt enable
            SETB    ET0           ; Timer0 interrupt enable

            ;--- Start Timer0 ---
            SETB    TR0

MAIN_LOOP:
            SJMP    MAIN_LOOP     ; Do nothing; the ISR does multiplexing

;----------------------------------------------------------------------
;  Timer0 Interrupt Service Routine
;  ~ every 5ms: reload Timer0, pick next digit, output BCD + select bits
;----------------------------------------------------------------------
TIMER0_ISR:
            ;--- Reload Timer0 for next 5ms ---
            MOV     TH0, #0xEC
            MOV     TL0, #0xC8
            CLR     TF0                 ; Clear overflow flag

            ;--- Get current digit index from “DigitIndex” in RAM ---
            MOV     A, DigitIndex       ; A = current digit 0..3

            ; (1) Get BCD code from BCD_TABLE
            MOV     DPTR, #BCD_TABLE
            MOVC    A, @A+DPTR          ; A = BCD for 1..4
            MOV     R7, A               ; Save BCD nibble in R7

            ; (2) Get the digit-select code from SEL_TABLE
            MOV     A, DigitIndex
            MOV     DPTR, #SEL_TABLE
            MOVC    A, @A+DPTR          ; A = 0..3 for bits P1.5..P1.4

            ; Shift that value into the top nibble (bits 7..4)
            ;  Because 0..3 in decimal is 00b..11b in binary, we can
            ;  shift left by 4 bits to move to P1.5–P1.4:
            MOV     B, A               ; B = select code 0..3
            CLR     A                  ; A=0
            MOV     C, 4               ; we want 4 shifts
SHIFT_LOOP:
            MOV   A, B     ; move B into accumulator A
            RL    A        ; rotate A left through carry
            MOV   B, A     ; store result back into B
            DJNZ    C, SHIFT_LOOP

            ; Now A holds the top nibble for P1.5–P1.4
            ; Merge with R7’s BCD nibble
            ORL     A, R7              ; A7..A4 = digit select, A3..A0 = BCD

            ;--- Send out to port ---
            MOV     P1, A

            ;--- Next digit index in RAM ---
            MOV     A, DigitIndex
            INC     A
            ANL     A, #03h            ; keep it 0..3
            MOV     DigitIndex, A

            RETI





            END