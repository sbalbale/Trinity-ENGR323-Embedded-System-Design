; ;-------------------------------------------------------------------------------
; ; Slave.a51  — UART‑slave with countup.asm display logic
; ;-------------------------------------------------------------------------------
;                 ORG     0000h
;                 AJMP    MAIN

;                 ORG     000Bh           ; Timer0 → display multiplex
;                 AJMP    Timer0_ISR

;                 ORG     0023h           ; Serial interrupt
;                 AJMP    SERIAL_ISR

;                 ORG     0030h           ; Use same area as countup.asm
; MAIN:
;     ; ===== Stack & Timer setup (countup.asm) =====
;     MOV     SP, #30h
;     MOV     TMOD, #21h       ; T1=mode2 for UART baud, T0=mode1 for display
;     ; Timer0 initial 5 ms (per countup.asm)
;     MOV     TH0, #0ECh
;     MOV     TL0, #078h
;     SETB    ET0
;     SETB    EA
;     SETB    TR0

;     ; ===== UART@9600, mode‑3, SM2=1, REN=1 =====
;     MOV     TH1, #0FDh
;     MOV     TL1, #0FDh
;     SETB    TR1
;     MOV     SCON, #0D0h
;     SETB    ES

;     ; ===== Initial display = “0000” =====
;     MOV     R0, #00h      ; ones digit = 0
;     MOV     R1, #00h      ; tens
;     MOV     R2, #00h      ; hundreds
;     MOV     R3, #00h      ; thousands
;     MOV     R4, #00h      ; display position

;     SJMP    $             ; spin; all work in ISRs

; ;-------------------------------------------------------------------------------
; ; Timer0 ISR: reload & multiplex (exact from countup.asm)
; ;-------------------------------------------------------------------------------
; Timer0_ISR:
;     PUSH    ACC
;     PUSH    PSW

;     ; — reload for ~5 ms
;     CLR     TR0
;     MOV     TH0, #0ECh
;     MOV     TL0, #08Bh
;     CLR     TF0
;     SETB    TR0

;     ; — display one digit
;     MOV     A, R4
;     CJNE    A, #00h, Try_Pos1
;         MOV     A, R3          ; thousands digit
;         SJMP    Output_Digit

; Try_Pos1:
;     CJNE    A, #01h, Try_Pos2
;         MOV     A, R2          ; hundreds
;         ORL     A, #10h
;         SJMP    Output_Digit

; Try_Pos2:
;     CJNE    A, #02h, Try_Pos3
;         MOV     A, R1          ; tens
;         ORL     A, #20h
;         SJMP    Output_Digit

; Try_Pos3:
;         MOV     A, R0          ; ones
;         ORL     A, #30h

; Output_Digit:
;     MOV     P1, A

;     ; — advance position 0→1→2→3→0
;     MOV     A, R4
;     INC     A
;     CJNE    A, #04h, Save_Pos
;         MOV     A, #00h
; Save_Pos:
;     MOV     R4, A

;     POP     PSW
;     POP     ACC
;     RETI

; ;-------------------------------------------------------------------------------
; ; Serial ISR: address vs data, sets R3:R0 for display
; ;-------------------------------------------------------------------------------
; SERIAL_ISR:
;     JNB     RI, Done
;     CLR     RI

;     ; — address byte? (RB8=1)
;     JNB     RB8, Got_Data

;     ; address path
;     MOV     A, SBUF
;     CJNE    A, #05h, Done     ; only slave #05
;     CLR     SM2               ; start data reception
;     ; show “9999”
;     MOV     R0, #09h
;     MOV     R1, #09h
;     MOV     R2, #09h
;     MOV     R3, #09h
;     SJMP    Done

; Got_Data:
;     ; — data byte
;     MOV     A, SBUF
;     ; store into XDATA or RAM as needed, e.g. MOVX @DPTR,A; INC DPTR
;     ; your existing save‑to‑RAM code goes here…

;     ; after storing Nth byte, convert and display:
;     ; tens → R1, ones → R0; clear high digits for “00XX” or “XXYY”
;     ; compute decimal digits in A/B:
;     ;   MOV B,#10
;     ;   DIV AB       ; A=quotient, B=remainder
;     ;   MOV     R1, A
;     ;   MOV     R0, B
;     ;   MOV     R2, #00h
;     ;   MOV     R3, #00h

;     ; delay ~1 s between bytes (busy‑wait)
;     ACALL  ONESEC_DELAY

; Done:
;     RETI

; ;-------------------------------------------------------------------------------
; ; ONESEC_DELAY: rough 1 s busy loop (tune to your crystal)
; ;-------------------------------------------------------------------------------
; ONESEC_DELAY:
;     MOV     R5, #200
; D1:
;     MOV     R6, #250
; D2:
;     DJNZ    R6, D2
;     DJNZ    R5, D1
;     RET

;                 END


;-------------------------------------------------------------------------------
; Slave.a51  — UART slave with 5 ms TDM scan & 1 s‑per‑digit display routine
;-------------------------------------------------------------------------------

                ORG     0000h
                AJMP    MAIN

                ORG     000Bh           ; Timer0 overflow → TDM scan
                AJMP    TDM_ISR

                ORG     0023h           ; Serial interrupt
                AJMP    SERIAL_ISR

;-------------------------------------------------------------------------------
; Variables in internal RAM
;-------------------------------------------------------------------------------
ONES        EQU     070h           ; digit 0 buffer (0x0N → ones place)
TENS        EQU     071h           ; digit 1 buffer (0x1N → tens place)
HUNDREDS    EQU     072h           ; digit 2 buffer (0x2N → hundreds/blank)
THOUSANDS   EQU     073h           ; digit 3 buffer (0x3N → thousands/blank)

DATA_START  EQU     030h           ; where to save incoming bytes
DATA_COUNT  EQU     064           ; number of bytes to save (0x3F+1)

DONE_FLAG   EQU     075h           ; set to 1 when all DATA_COUNT bytes received

;-------------------------------------------------------------------------------
; MAIN: init UART, timers, then wait/display loop
;-------------------------------------------------------------------------------
MAIN:
    ;––– UART @9600, Mode 3, SM2=1, REN=1 –––
    MOV     TMOD,   #21h        ; T1 mode2 for baud, T0 mode1 for display
    MOV     TH1,    #0FDh       ; reload for 9600 @ 11.0592 MHz
    MOV     TL1,    #0FDh
    SETB    TR1
    MOV     SCON,   #0D0h       ; SM0=1,SM1=1 (mode3), SM2=1, REN=1
    SETB    ES
    SETB    EA

    ;––– Timer0 setup for ~5 ms interrupts (EDFFh → 1200d) –––
    MOV     TH0,    #0EDh
    MOV     TL0,    #0FFh
    SETB    ET0
    SETB    TR0

    ;––– Initialize display to “0000” –––
    MOV     ONES,      #00h      ; 0 at ones
    MOV     TENS,      #10h      ; 0 at tens
    MOV     HUNDREDS,  #20h      ; blank hundreds
    MOV     THOUSANDS, #30h      ; blank thousands
    MOV     R0,        #070h     ; pointer into ONES…THOUSANDS block

    ;––– Clear DONE_FLAG –––
    CLR     DONE_FLAG

main_loop:
    ; wait for all bytes received
    JNB     DONE_FLAG, main_loop
    CLR     DONE_FLAG

    ;––– 1) Show “9999” for 1 s –––
    MOV     ONES,      #09h
    MOV     TENS,      #19h
    MOV     HUNDREDS,  #29h
    MOV     THOUSANDS, #39h
    ACALL   ONESEC_DELAY

    ;––– 2) Display each saved byte with 1 s between –––
    MOV     R1,        #DATA_START  ; R1 → save address
    MOV     R7,        #DATA_COUNT  ; R7 → count

disp_loop:
    MOV     A,  @R1               ; fetch byte
    MOV     B,  #10
    DIV     AB                    ; A=tens, B=ones

    ; tens digit into TENS
    MOV     TENS,  A
    ORL     TENS,  #20h           ; set position=1

    ; ones digit into ONES
    MOV     ONES,  B             
    ORL     ONES,  #30h           ; set position=3

    ; blank left two digits
    MOV     HUNDREDS, #10h
    MOV     THOUSANDS,#00h

    ACALL   ONESEC_DELAY

    INC     R1
    DJNZ    R7, disp_loop

    SJMP    main_loop

;-------------------------------------------------------------------------------
; Timer0 ISR: 5 ms TDM scan (exact from countup.asm)
;-------------------------------------------------------------------------------
TDM_ISR:
    PUSH    ACC
    PUSH    PSW

    CLR     TR0
    MOV     TH0,   #0ECh       ; high byte for ~5 ms
    MOV     TL0,   #07Ch       ; low byte  for ~5 ms
    CLR     TF0
    SETB    TR0

    ; output the “segment+position” byte
    MOV     P1,    @R0
    INC     R0
    CJNE    R0,    #074h, TDM_DONE
        MOV     R0,    #070h     ; wrap back
TDM_DONE:

    POP     PSW
    POP     ACC
    RETI

;-------------------------------------------------------------------------------
; SERIAL ISR: address vs. data, save to RAM, set DONE_FLAG at end
;-------------------------------------------------------------------------------
SERIAL_ISR:
    JNB     RI,    _ser_end
    CLR     RI

    ; address byte? RB8=1
    JNB     RB8,   _data
    ; —— address path ——
    MOV     A,     SBUF
    CJNE    A,     #05h, _ser_end  ; only slave 0x05
    CLR     SM2                      ; now accept data bytes
    MOV     R1,    #DATA_START      ; init save ptr
    MOV     R7,    #DATA_COUNT      ; init byte count
    SJMP    _ser_end

_data:
    ; —— data byte path ——
    MOV     A,     SBUF
    MOV     @R1,   A               ; save into 0x30–0x6F
    INC     R1
    DJNZ    R7,    _ser_end        ; still more to come

    ; —— all bytes in! ——
    SETB    DONE_FLAG

_ser_end:
    RETI

;-------------------------------------------------------------------------------
; ONESEC_DELAY: rough 1 s busy‑wait (200×250 loops ≈1 s @12 µs/loop)
; interrupts remain enabled so TDM_ISR keeps scanning
;-------------------------------------------------------------------------------
ONESEC_DELAY:
    MOV     R5,    #200
DLY1:
    MOV     R6,    #250
DLY2:
    DJNZ    R6,    DLY2
    DJNZ    R5,    DLY1
    RET

                END