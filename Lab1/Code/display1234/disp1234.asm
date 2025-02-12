            ORG     0000h           
            AJMP    MAIN           

            ORG     000Bh          ; Timer 0 interrupt vector
            AJMP    Timer0_ISR

            ORG     0030h          
MAIN:       MOV     SP, #30h       ; Initialize stack pointer
            MOV     TMOD, #01h     ; Timer 0, mode 1 (16-bit)

            ; Timer 0 setup for 5ms (12MHz clock)
            ; 5ms = 5000us = 5000 machine cycles
            ; 65536 - 5000 = 60536 (EC78h)
            MOV     TH0, #0ECh     
            MOV     TL0, #078h     

            ; Store display digits in RAM
            MOV     20h, #01h      ; Position 0 - digit 1
            MOV     21h, #12h      ; Position 1 - digit 2
            MOV     22h, #23h      ; Position 2 - digit 3
            MOV     23h, #34h      ; Position 3 - digit 4
            MOV     24h, #00h      ; Current display position

            ; Enable interrupts
            SETB    ET0            ; Enable Timer 0 interrupt
            SETB    EA             ; Enable global interrupts
            SETB    TR0            ; Start Timer 0

MainLoop:   SJMP    MainLoop       ; Main program loop

Timer0_ISR: PUSH    ACC            
            PUSH    PSW

            ; Reload timer for next 5ms
            CLR     TR0            
            MOV     TH0, #0ECh     
            MOV     TL0, #078h     
            CLR     TF0            
            SETB    TR0            

            ; Get current position and display digit
            MOV     A, 24h         ; Get current position
            MOV     DPTR, #DispTab ; Point to display table
            MOVC    A, @A+DPTR     ; Get display pattern
            MOV     P1, A          ; Output to display

            ; Update position counter
            MOV     A, 24h
            INC     A              ; Increment position
            CJNE    A, #04h, Save_Pos
            MOV     A, #00h        ; Reset to 0 if reached 4
Save_Pos:   MOV     24h, A         

            POP     PSW            
            POP     ACC
            RETI

; Display patterns table
DispTab:    DB      01h           ; Digit 1, position 0
            DB      12h           ; Digit 2, position 1
            DB      23h           ; Digit 3, position 2
            DB      34h           ; Digit 4, position 3

            END