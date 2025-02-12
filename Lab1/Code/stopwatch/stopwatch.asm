ORG 0000h
    AJMP MainProg

ORG 000Bh                  ; Timer 0 interrupt vector
    AJMP Timer0_ISR

ORG 0100h
MainProg:
    MOV SP, #30h          ; Initialize stack pointer
    MOV TMOD, #01h        ; Timer 0, mode 1 (16-bit)

    ; Initialize Timer 0 for 5ms interrupts (12MHz clock)
    MOV TH0, #0ECh        ; Load timer high byte
    MOV TL0, #078h        ; Load timer low byte

    ; Initialize display digits in RAM
    MOV 20h, #01h         ; First digit (1)
    MOV 21h, #02h         ; Second digit (2)
    MOV 22h, #03h         ; Third digit (3)
    MOV 23h, #04h         ; Fourth digit (4)
    MOV 24h, #00h         ; Current display position (0-3)

    ; Enable interrupts
    SETB ET0              ; Enable Timer 0 interrupt
    SETB EA               ; Enable global interrupts
    SETB TR0              ; Start Timer 0

MainLoop:
    SJMP MainLoop         ; Main program loop (empty)

Timer0_ISR:
    PUSH ACC              ; Save accumulator
    PUSH PSW              ; Save program status word

    ; Reload timer for next 5ms interrupt
    CLR TR0               ; Stop timer
    MOV TH0, #0ECh        ; Reload high byte
    MOV TL0, #077h        ; Reload low byte
    CLR TF0               ; Clear overflow flag
    SETB TR0              ; Restart timer

    ; Get current display position
    MOV A, 24h            ; Load current position

    ; Display digit based on position
    CJNE A, #00h, Try_Pos1
    MOV A, 20h            ; Get digit 1
    ANL A, #0Fh           ; Mask for BCD
    SJMP Output_Digit

Try_Pos1:
    CJNE A, #01h, Try_Pos2
    MOV A, 21h            ; Get digit 2
    ANL A, #0Fh           ; Mask for BCD
    ORL A, #010h          ; Set DMUX for position 1
    SJMP Output_Digit

Try_Pos2:
    CJNE A, #02h, Try_Pos3
    MOV A, 22h            ; Get digit 3
    ANL A, #0Fh           ; Mask for BCD
    ORL A, #020h          ; Set DMUX for position 2
    SJMP Output_Digit

Try_Pos3:
    MOV A, 23h            ; Get digit 4
    ANL A, #0Fh           ; Mask for BCD
    ORL A, #030h          ; Set DMUX for position 3

Output_Digit:
    MOV P1, A             ; Output to display

    ; Update position counter
    MOV A, 24h
    INC A                 ; Increment position
    CJNE A, #04h, Save_Pos
    MOV A, #00h           ; Reset to 0 if reached 4

Save_Pos:
    MOV 24h, A            ; Save new position

    POP PSW               ; Restore program status word
    POP ACC               ; Restore accumulator
    RETI

END