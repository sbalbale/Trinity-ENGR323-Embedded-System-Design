ORG 0000h        ; Reset vector
AJMP MainProg   ; Jump to main program

ORG 000Bh        ; Timer0 (TF0) interrupt vector (must be ≤8 bytes)
AJMP ISRTF0     ; Jump to Timer0 ISR

ORG 0100h        ; Start of main program
MainProg:
    MOV SP, #35h    ; Set stack pointer
    MOV TMOD, #11h  ; Configure Timer0 and Timer1 in mode 1 (16-bit mode)
                      ; Set Timer0 initial value (not critical, since we reload in ISR)
    MOV TH0, #0ECh    
    MOV TL0, #078h    
    SETB TR0        ; Start Timer0
    SETB EA         ; Enable global interrupts
    SETB ET0        ; Enable Timer0 interrupt

  ; Initialize counter variables in internal RAM
    MOV 30h, #00h   ; Seconds units digit
    MOV 31h, #00h   ; Seconds tens digit
    MOV 32h, #00h   ; Minutes units digit
    MOV 33h, #00h   ; Minutes tens digit

WaitLoop:
    NOP
    SJMP WaitLoop    ; Main loop does nothing—display refresh is handled in ISR;-----------------------------------------------------; Timer0 ISR: Refresh one 7-seg digit per interrupt every 5ms;-----------------------------------------------------
ISRTF0:
    PUSH ACC         ; Save registers used in ISR
    PUSH PSW

  ; Reload Timer0 for a 5ms interval.
  ; With a 12MHz clock (1µs per machine cycle), 5000 counts are needed.
  ; Reload value = 65536 - 5000 = 60536 = 0xEC78.
    MOV TH0, #0ECh  ; High byte = 0xEC (236 decimal)
    MOV TL0, #078h  ; Low byte  = 0x78 (120 decimal)

  ; Get current digit index from RAM (at address 30h)
    MOV A, 30h

  ; Select the digit to display based on the digit index:
    CJNE A, #00h, Check1
  ; For index 0: display seconds units digit with demux enable 0x00
    MOV A, 30h      ; Load seconds units digit
    ANL A, #0Fh      ; Clear the upper nibble to keep the value between 0x00 and 0x09
    SJMP UpdateDigit
Check1:
    CJNE A, #01h, Check2
  ; For index 1: display seconds tens digit with demux enable 0x10
    MOV A, 31h      ; Load seconds tens digit
    ANL A, #0Fh      ; Clear the upper nibble to keep the value between 0x00 and 0x05
    ORL A, #10h     ; Set the demux enable bit
    SJMP UpdateDigit
Check2:
    CJNE A, #02h, Check3
  ; For index 2: display minutes units digit with demux enable 0x20
    MOV A, 32h      ; Load minutes units digit
    ANL A, #0Fh      ; Clear the upper nibble to keep the value between 0x00 and 0x09
    ORL A, #20h     ; Set the demux enable bit
    SJMP UpdateDigit
Check3:
  ; For index 3: display minutes tens digit with demux enable 0x40
    MOV A, 33h      ; Load minutes tens digit
    ANL A, #0Fh      ; Clear the upper nibble to keep the value between 0x00 and 0x04
    ORL A, #40h     ; Set the demux enable bit

UpdateDigit:
    MOV P1, A       ; Output the BCD+demux pattern to Port1

  ; Increment digit index and wrap back to 0 after 3
    MOV A, 30h
    INC A
    CJNE A, #04h, NoWrap
    MOV A, #00h     ; Reset index after 4 digits
NoWrap:
    MOV 30h, A                ; Store the updated digit index

  ; Increment counters (this should be done outside the digit index wrapping logic)
    MOV A, 30h     ; Load seconds units digit into accumulator
    CJNE A, #09h, NoSecWrap; Check if seconds units needs wrapping
    MOV 30h, #00h             ; Wrap seconds units
    INC 31h                   ; Increment seconds tens
    MOV A, 31h     ; Load seconds tens digit into accumulator
    CJNE A, #05h, NoSecWrap; Check if seconds tens needs wrapping
    MOV 31h, #00h             ; Wrap seconds tens
    INC 32h                   ; Increment minutes units
    MOV A, 32h     ; Load minutes units digit into accumulator
    CJNE A, #09h, NoSecWrap; Check if minutes units needs wrapping
    MOV 32h, #00h             ; Wrap minutes units
    INC 33h                   ; Increment minutes tens
NoSecWrap:

    POP PSW         ; Restore registers
    POP ACC
    RETI             ; Return from interrupt

END