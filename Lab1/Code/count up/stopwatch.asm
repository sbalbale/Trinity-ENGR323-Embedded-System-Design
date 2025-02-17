            ORG     0000h           
            AJMP    MAIN           

            ORG     000Bh          
            AJMP    Timer0_ISR

            ORG     0030h          
MAIN:       MOV     SP, #30h       
            MOV     TMOD, #01h     

            ; Timer 0 setup for 5ms
            MOV     TH0, #0ECh     
            MOV     TL0, #078h     

            ; Initialize registers for time values
            MOV     R0, #00h      ; 1 second digit
            MOV     R1, #00h      ; 10 seconds digit
            MOV     R2, #00h      ; 1 minute digit
            MOV     R3, #00h      ; 10 minutes digit
            MOV     R4, #00h      ; Display position
            MOV     R5, #00h      ; Counter for 1 second (200 * 5ms = 1000ms)
            
            ; Enable interrupts
            SETB    ET0            
            SETB    EA             
            SETB    TR0            

MainLoop:   SJMP    MainLoop       

;this loop takes aproximatly 70 machine cycles. Timer value might need to be adjusted to  0xECh, 0xBDh.
; default value is 0xECh, 0x77h
Timer0_ISR: PUSH    ACC            
            PUSH    PSW

            ; Reload timer
            CLR     TR0            
            MOV     TH0, #0ECh     
            MOV     TL0, #08Bh     
            CLR     TF0            
            SETB    TR0            

            ; Update time counter
            INC     R5             ; Increment ms counter
            MOV     A, R5
            CJNE    A, #0C8h, Display    ; 200 * 5ms = 1 second
            MOV     R5, #00h       ; Reset ms counter

            ; Update seconds
            INC     R0             ; Increment ones second
            MOV     A, R0
            CJNE    A, #0Ah, Display    ; If not 10
            MOV     R0, #00h       ; Reset ones second
            
            ; Update tens seconds
            INC     R1             ; Increment tens seconds
            MOV     A, R1
            CJNE    A, #06h, Display    ; If not 60 seconds
            MOV     R1, #00h       ; Reset tens seconds
            
            ; Update minutes
            INC     R2             ; Increment minutes
            MOV     A, R2
            CJNE    A, #0Ah, Display    ; If not 10 minutes
            MOV     R2, #00h       ; Reset minutes
            
            ; Update tens minutes
            INC     R3             ; Increment tens minutes
            MOV     A, R3
            CJNE    A, #06h, Display    ; If not 60 minutes
            MOV     R3, #00h       ; Reset tens minutes

Display:    ; Get current position and display digit
            MOV     A, R4          
            CJNE    A, #00h, Try_Pos1
            MOV     A, R3          ; Get 10 minutes
            SJMP    Output_Digit

Try_Pos1:   CJNE    A, #01h, Try_Pos2
            MOV     A, R2          ; Get 1 minute
            ORL     A, #10h        
            SJMP    Output_Digit

Try_Pos2:   CJNE    A, #02h, Try_Pos3
            MOV     A, R1          ; Get 10 seconds
            ORL     A, #20h        
            SJMP    Output_Digit

Try_Pos3:   MOV     A, R0          ; Get 1 second
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

            END