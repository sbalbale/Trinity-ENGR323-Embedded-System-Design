            MY_ADDR       EQU   05h       ; Slave's own address (must match master)
            
            ORG     0000h           
            AJMP    MAIN           

            ORG     0023h          ; Serial port interrupt vector
            AJMP    SERIAL_ISR           

            ORG     000Bh          ; Timer 0 vector
            AJMP    Timer0_ISR

            ORG     0100h          
MAIN:       MOV     SP, #30h       
            MOV     TMOD, #21h     ; Timer 0: mode 1 (16-bit), Timer 1: mode 2 (8-bit auto-reload)

            ; Initialize display registers (Bank 0)
            CLR     RS0            ; Select Bank 0
            CLR     RS1
            MOV     R0, #00h      ; Ones digit
            MOV     R1, #00h      ; Tens digit
            MOV     R2, #00h      ; Hundreds digit
            MOV     R3, #00h      ; Thousands digit
            MOV     R4, #00h      ; Display position
            MOV     R5, #00h      ; Counter for 5ms intervals
            
            
            ; Timer 0 setup for 5ms display refresh
            MOV     TH0, #0ECh     
            MOV     TL0, #078h
            SETB    ET0           ; Enable Timer 0 interrupt
            
            ; UART setup
            MOV     SCON, #50h    ; Serial mode 1 (8-bit UART), REN=1 (enable receiver)
            MOV     TH1, #0FDh    ; 9600 baud rate with 11.0592 MHz crystal
            SETB    TR1           ; Start Timer 1
            SETB    ES            ; Enable serial interrupt
            
            SETB    EA            ; Enable global interrupts
            SETB    TR0           ; Start Timer 0

MainLoop:   SJMP    MainLoop      ; Everything handled by interrupts

; Timer 0 ISR - Display refresh
Timer0_ISR: PUSH    ACC            
            PUSH    PSW

            ; Reload timer for next 5ms
            CLR     TR0            
            MOV     TH0, #0ECh     
            MOV     TL0, #078h     
            CLR     TF0            
            SETB    TR0     

            SJMP    Display_Update


; Serial Interrupt (UART receive)
SERIAL_ISR: PUSH    ACC
            PUSH    PSW
            
            JNB     RI, Exit_Serial    ; If not receive interrupt, exit
            CLR     RI                  ; Clear receive interrupt flag
            
            MOV     A, SBUF            ; Get received byte
            
            ; Convert to BCD digits for display
            MOV     B, #100
            DIV     AB                  ; A = value/100, B = value%100
            MOV     R2, A               ; Hundreds digit
            
            MOV     A, B
            MOV     B, #10
            DIV     AB                  ; A = (value%100)/10, B = value%10
            MOV     R1, A               ; Tens digit
            MOV     R0, B               ; Ones digit
            
            ; If number > 255, set thousands digit to 0
            ; If we're receiving 8-bit values, this will always be 0
            MOV     R3, #00h
            
            ; ; Display "1" when UART data is received
            ; MOV     R0, #1             ; Ones digit = 1
            ; MOV     R1, #0             ; Tens digit = 0
            ; MOV     R2, #0             ; Hundreds digit = 0
            ; MOV     R3, #0             ; Thousands digit = 0


Exit_Serial:
            POP     PSW
            POP     ACC
            RETI
Display_Update:
            ; Select digit to display using position code in high nibble
            MOV     A, R4          
            CJNE    A, #00h, Try_Pos1
            MOV     A, R0          ; First digit (thousands)
            ORL     A, #00h        ; Position 0 code (00h)
            SJMP    Output_Digit

Try_Pos1:   CJNE    A, #01h, Try_Pos2
            MOV     A, R1          ; Second digit (hundreds)
            ORL     A, #10h        ; Position 1 code (10h)
            SJMP    Output_Digit

Try_Pos2:   CJNE    A, #02h, Try_Pos3
            MOV     A, R2          ; Third digit (tens)
            ORL     A, #20h        ; Position 2 code (20h)
            SJMP    Output_Digit

Try_Pos3:   MOV     A, R3          ; Fourth digit (ones)
            ORL     A, #30h        ; Position 3 code (30h)

Output_Digit:
            ANL     A, #3Fh        ; Ensure upper 2 bits are clear
            MOV     P1, A          ; Output digit value with position code

            ; Update display position
            MOV     A, R4
            INC     A              
            CJNE    A, #04h, Save_Pos
            CLR     A             
Save_Pos:   MOV     R4, A         

            POP     PSW            
            POP     ACC
            RETI

            END