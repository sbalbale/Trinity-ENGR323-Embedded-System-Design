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
            MOV     R0, #00h      ; 1/100 digit
            MOV     R1, #00h      ; 1/10 digit
            MOV     R2, #00h      ; Ones digit
            MOV     R3, #00h      ; Tens digit
            MOV     R4, #00h      ; Display position
            MOV     R5, #00h      ; 5ms counter for 1 second tracking
            
            ; Initialize click tracking
            MOV     20h, #00h     ; Click counter low byte
            MOV     21h, #00h     ; Click counter high byte
            MOV     22h, #00h     ; Seconds counter
            
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

            ; Increment 5ms counter
            INC     R5
            MOV     A, R5
            CJNE    A, #0C8h, Display_Update  ; 200 * 5ms = 1 second
            MOV     R5, #00h     

            ; Increment seconds counter
            INC     22h
            MOV     A, 22h
            CJNE    A, #3Ch, Calc_CPM  ; 60 seconds = 1 minute
            MOV     22h, #00h     ; Reset seconds

            ; Calculate Clicks Per Minute (CPM)
Calc_CPM:   MOV     A, 20h        ; Low byte of click count
            MOV     B, #60        ; Divide by current seconds count
            DIV     AB            ; Divide click count by seconds elapsed
            MOV     R2, A         ; Ones digit
            MOV     R1, B         ; Remainder (for tenths)

            ; Convert remainder to tenths
            MOV     A, R1
            MOV     B, #10
            DIV     AB
            MOV     R0, A         ; Tenths digit
            MOV     R1, B         ; Hundredths digit
            
            ; Clear tens digit if clicks per minute is less than 100
            MOV     R3, #00h
            
            ; If result is over 99, set to 99
            CJNE    A, #0Ah, Display_Update
            MOV     R2, #09h
            MOV     R1, #09h
            MOV     R0, #09h
            MOV     R3, #09h

Display_Update:
            ; Display routine
            MOV     A, R4          
            CJNE    A, #00h, Pos1
            MOV     A, R3         ; Tens digit
            SJMP    Output_Digit

Pos1:       CJNE    A, #01h, Pos2
            MOV     A, R2         ; Ones digit
            ORL     A, #10h        
            SJMP    Output_Digit

Pos2:       CJNE    A, #02h, Pos3
            MOV     A, R1         ; Tenths digit
            ORL     A, #20h        
            SJMP    Output_Digit

Pos3:       MOV     A, R0         ; Hundredths digit
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
            
            ; Increment click counter
            INC     20h            ; Increment low byte
            MOV     A, 20h
            JNZ     EXT0_ISR_Exit  ; If no rollover, exit
            INC     21h            ; Increment high byte if low byte rolled over

EXT0_ISR_Exit:
            POP     PSW
            POP     ACC
            RETI

            END