ORG     0000h           
            AJMP    MAIN           

            ORG     0003h          ; External Interrupt 0 vector
            AJMP    EXT0_ISR           

            ORG     000Bh          ; Timer 0 vector
            AJMP    Timer0_ISR

            ORG     0100h          
MAIN:       MOV     SP, #30h       
            MOV     TMOD, #01h     ; Timer 0, mode 1 (16-bit)

            ; Initialize registers
            CLR     RS0            ; Select Bank 0
            CLR     RS1
            MOV     R0, #00h      ; 1/100 second digit
            MOV     R1, #00h      ; 1/10 second digit
            MOV     R2, #00h      ; seconds digit
            MOV     R3, #00h      ; 10 seconds digit
            MOV     R4, #00h      ; Display position
            
            ; Initialize interval tracking
            MOV     20h, #00h     ; First interrupt flag (0=waiting first pulse, 1=measuring)
            MOV     21h, #00h     ; Interval high byte
            MOV     22h, #00h     ; Interval low byte
            
            ; Timer 0 setup for 5ms
            MOV     TH0, #0ECh     
            MOV     TL0, #078h
            SETB    TR0           ; Start Timer 0
            
            ; Setup External Interrupt 0
            SETB    IT0           ; Falling edge triggered
            SETB    EX0           ; Enable INT0
            
            ; Enable interrupts
            SETB    ET0           ; Enable Timer 0 interrupt
            SETB    EA            ; Enable global interrupts

MainLoop:   SJMP    MainLoop      ; Everything handled by interrupts

Timer0_ISR: PUSH    ACC            
            PUSH    PSW

            ; Reload timer for next 5ms
            CLR     TR0            
            MOV     TH0, #0ECh     
            MOV     TL0, #08Ch     
            CLR     TF0            
            SETB    TR0            

            ; Check if we're measuring interval
            MOV     A, 20h
            JZ      Display_Update

            ; Increment interval time tracking
            INC     22h            ; Increment low byte
            MOV     A, 22h
            JNZ     Display_Update ; If low byte didn't roll over, skip
            INC     21h            ; Increment high byte if low byte rolled over

Display_Update:
            ; Update display digits
            MOV     A, 21h         ; High byte of interval
            MOV     B, #10         ; Divide by 10 for display
            DIV     AB
            MOV     R3, A          ; 10 seconds digit (high byte / 10)
            
            MOV     A, 22h         ; Low byte of interval
            MOV     B, #10         ; Divide by 10
            DIV     AB
            MOV     R2, A          ; Seconds digit (quotient)
            MOV     R1, B          ; 1/10 seconds (remainder)
            
            ; Convert remainder to 1/100 seconds
            MOV     A, R1
            MOV     B, #10
            DIV     AB
            MOV     R0, A          ; 1/10 seconds
            MOV     R1, B          ; 1/100 seconds

            ; Display routine (similar to previous programs)
            MOV     A, R4          
            CJNE    A, #00h, Pos1
            MOV     A, R3         ; 10 seconds
            SJMP    Output_Digit

Pos1:       CJNE    A, #01h, Pos2
            MOV     A, R2         ; Seconds
            ORL     A, #10h        
            SJMP    Output_Digit

Pos2:       CJNE    A, #02h, Pos3
            MOV     A, R1         ; 1/10 second
            ORL     A, #20h        
            SJMP    Output_Digit

Pos3:       MOV     A, R0         ; 1/100 second
            ORL     A, #30h        

Output_Digit:
            MOV     P1, A          

            ; Update display position
            MOV     A, R4
            INC     A              
            CJNE    A, #04h, Save_Pos
            MOV     A, #00h        
Save_Pos:   MOV     R4, A         

            POP     PSW            
            POP     ACC
            RETI

EXT0_ISR:   PUSH    ACC
            PUSH    PSW
            
            ; Check if this is the first interrupt
            MOV     A, 20h
            JNZ     Stop_Interval

            ; First interrupt - start measuring
            MOV     20h, #01h     ; Set measuring flag
            MOV     21h, #00h     ; Reset high byte
            MOV     22h, #00h     ; Reset low byte
            SJMP    EXT0_ISR_Exit

Stop_Interval:
            ; Second interrupt - stop measuring and display
            MOV     20h, #00h     ; Reset first interrupt flag

EXT0_ISR_Exit:
            POP     PSW
            POP     ACC
            RETI

            END