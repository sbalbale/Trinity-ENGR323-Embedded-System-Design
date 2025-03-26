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
            MOV     R2, #00h      ; Seconds digit
            MOV     R3, #00h      ; 10 seconds digit
            MOV     R4, #00h      ; Display position
            MOV     R5, #00h      ; Counter for 5ms intervals
            
            ; Initialize click state
            MOV     20h, #00h     ; Click state (0=Waiting for first click, 1=Timing between clicks)
            
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

            ; Check if we're timing between clicks
            MOV     A, 20h
            JZ      Display_Update   ; If 0, we're not timing yet

            ; Update stopwatch every 2 intervals (10ms) - from stopwatch.asm
            MOV     A, R5
            INC     R5            ; Increment interval counter
            ANL     A, #01h       ; Check if even number
            JNZ     Display_Update

            ; Update stopwatch digits (using stopwatch.asm timing logic)
            INC     R0           ; 1/100 seconds
            MOV     A, R0
            CJNE    A, #0Ah, Display_Update
            MOV     R0, #00h
            
            INC     R1           ; 1/10 seconds
            MOV     A, R1
            CJNE    A, #0Ah, Display_Update
            MOV     R1, #00h
            
            INC     R2           ; Seconds
            MOV     A, R2
            CJNE    A, #0Ah, Display_Update
            MOV     R2, #00h
            
            INC     R3           ; 10 seconds
            MOV     A, R3
            CJNE    A, #06h, Display_Update
            MOV     R3, #00h

Display_Update:
            ; Display logic from stopwatch.asm
            MOV     A, R4          
            CJNE    A, #00h, Stop_Pos1
            MOV     A, R3         ; 10 seconds
            SJMP    Output_Digit

Stop_Pos1:  CJNE    A, #01h, Stop_Pos2
            MOV     A, R2         ; Seconds
            ORL     A, #10h        
            SJMP    Output_Digit

Stop_Pos2:  CJNE    A, #02h, Stop_Pos3
            MOV     A, R1         ; 1/10 second
            ORL     A, #20h        
            SJMP    Output_Digit

Stop_Pos3:  MOV     A, R0         ; 1/100 second
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
            
            ; Check if this is the first click
            MOV     A, 20h
            JNZ     Second_Click

            ; First click - start timer
            MOV     20h, #01h     ; Set timing flag
            ; Reset all counters
            MOV     R0, #00h      ; 1/100 second
            MOV     R1, #00h      ; 1/10 second
            MOV     R2, #00h      ; seconds
            MOV     R3, #00h      ; 10 seconds
            MOV     R5, #00h      ; Reset interval counter
            SJMP    EXT0_ISR_Exit

Second_Click:
            ; Second click - stop timer
            MOV     20h, #00h     ; Reset timing flag
            ; Time is now shown on display

EXT0_ISR_Exit:
            POP     PSW
            POP     ACC
            RETI

            END