ORG     0000h           
            AJMP    MAIN           

            ORG     0013h          ; External Interrupt 1 vector
            AJMP    EXT1_ISR           

            ORG     000Bh          ; Timer 0 vector
            AJMP    Timer0_ISR

            ORG     0100h          
MAIN:       MOV     SP, #30h       
            MOV     TMOD, #01h     ; Timer 0, mode 1 (16-bit)

            ; Initialize button counter registers
            MOV     30h, #00h      ; Total button presses
            MOV     31h, #00h      ; Presses in current minute
            MOV     33h, #00h      ; Seconds counter
            MOV     34h, #00h      ; Minutes counter

            ; Initialize display registers
            MOV     R4, #00h       ; Display position
            MOV     R0, #00h       ; Right digit (ones)
            MOV     R1, #00h       ; Second digit (tens)
            MOV     R2, #00h       ; Third digit (hundreds)
            MOV     R3, #00h       ; Left digit (thousands)
            MOV     R5, #00h       ; Counter for 5ms intervals
            MOV     R7, #00h       ; Counter for 1 second intervals
            
            ; Setup External Interrupt 1
            SETB    IT1            ; Falling edge triggered
            SETB    EX1            ; Enable INT1
            
            ; Timer 0 setup for 5ms
            MOV     TH0, #0ECh     
            MOV     TL0, #078h
            SETB    ET0            ; Enable Timer 0
            SETB    EA             ; Enable global interrupts
            SETB    TR0            ; Start Timer 0

MainLoop:   SJMP    MainLoop       ; Everything handled by interrupts

; Timer 0 ISR - Display refresh and clock update
Timer0_ISR: PUSH    ACC            
            PUSH    PSW

            ; Reload timer for next 5ms
            CLR     TR0            
            MOV     TH0, #0ECh     
            MOV     TL0, #078h     
            CLR     TF0            
            SETB    TR0            

            ; Increment counter for 1 second timing
            INC     R7
            MOV     A, R7
            CJNE    A, #200, Display_Refresh  ; 200 * 5ms = 1 second
            MOV     R7, #00h

            ; Update clock
            INC     33h            ; Increment seconds
            MOV     A, 33h
            CJNE    A, #60, Display_Refresh
            MOV     33h, #00h      ; Reset seconds

            ; Update minute and reset press counter
            INC     34h            ; Increment minutes
            MOV     31h, #00h      ; Reset presses in current minute

Display_Refresh:
            ; Update display with presses per minute
            MOV     A, 31h         ; Get presses in current minute
            MOV     B, #100
            DIV     AB             ; A = hundreds, B = remainder
            MOV     R2, A          ; Store hundreds digit
            
            MOV     A, B           ; Get tens and ones
            MOV     B, #10
            DIV     AB             ; A = tens, B = ones
            MOV     R1, A          ; Store tens digit
            MOV     R0, B          ; Store ones digit
            MOV     R3, #00h       ; Thousands digit (always 0)

            ; Select digit to display
            MOV     A, R4          
            CJNE    A, #00h, Try_Pos1
            MOV     A, R0          ; Ones digit (rightmost)
            ORL     A, #30h        ; Position 3 code
            SJMP    Output_Digit

Try_Pos1:   CJNE    A, #01h, Try_Pos2
            MOV     A, R1          ; Tens digit
            ORL     A, #20h        ; Position 2 code
            SJMP    Output_Digit

Try_Pos2:   CJNE    A, #02h, Try_Pos3
            MOV     A, R2          ; Hundreds digit
            ORL     A, #10h        ; Position 1 code
            SJMP    Output_Digit

Try_Pos3:   MOV     A, R3          ; Thousands digit (leftmost)
            ORL     A, #00h        ; Position 0 code

Output_Digit:
            ANL     A, #3Fh        ; Ensure upper 2 bits are clear
            MOV     P1, A          ; Output digit value with position code

            ; Update display position
            MOV     A, R4
            INC     A              
            CJNE    A, #04h, Save_Pos
            MOV     A, #00h        
Save_Pos:   MOV     R4, A         

            POP     PSW            
            POP     ACC
            RETI

; External Interrupt 1 - Button press
EXT1_ISR:   PUSH    ACC
            PUSH    PSW
            
            ; Increment total press count
            INC     30h
            
            ; Increment current minute press count
            INC     31h
            
            POP     PSW
            POP     ACC
            RETI

            END
