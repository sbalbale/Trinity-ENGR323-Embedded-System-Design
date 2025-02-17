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


; MSECDelay:  MOV     R7, #0C7h    ; 199 * 1us = 1ms
; BackA:      DEC    R7
;             NOP
;             NOP
;             CJNE   R7, #000h, BackA
;             RET
     

MainLoop:   ; Check if 1 second has elapsed
            MOV     A, R5
            CJNE    A, #0C8h, MainLoop  ; Wait for 200 * 5ms
            MOV     R5, #00h      ; Reset counter

            ; Update seconds
            INC     R0            ; Increment ones second
            MOV     A, R0
            CJNE    A, #0Ah, MainLoop  
            MOV     R0, #00h      ; Reset ones second
            
            ; Update tens seconds
            INC     R1            ; Increment tens seconds
            MOV     A, R1
            CJNE    A, #06h, MainLoop  
            MOV     R1, #00h      ; Reset tens seconds
            
            ; Update minutes
            INC     R2            ; Increment minutes
            MOV     A, R2
            CJNE    A, #0Ah, MainLoop  
            MOV     R2, #00h      ; Reset minutes
            
            ; Update tens minutes
            INC     R3            ; Increment tens minutes
            MOV     A, R3
            CJNE    A, #06h, MainLoop  
            MOV     R3, #00h      ; Reset tens minutes
            
            SJMP    MainLoop      

Timer0_ISR: PUSH    ACC            
            PUSH    PSW

            ; Reload timer for next 5ms
            ;default value is 0x0EC78
            ;adjusting for cycle time test value of 0x0EC8C
            CLR     TR0            
            MOV     TH0, #0ECh     
            MOV     TL0, #08Ch     
            CLR     TF0            
            SETB    TR0            

            ; Increment 5ms counter
            INC     R5            ; For main loop timing

            ; Display multiplexing
            MOV     A, R4          
            CJNE    A, #00h, Try_Pos1
            MOV     A, R3          ; Display 10 minutes
            SJMP    Output_Digit

Try_Pos1:   CJNE    A, #01h, Try_Pos2
            MOV     A, R2          ; Display 1 minute
            ORL     A, #10h        
            SJMP    Output_Digit

Try_Pos2:   CJNE    A, #02h, Try_Pos3
            MOV     A, R1          ; Display 10 seconds
            ORL     A, #20h        
            SJMP    Output_Digit

Try_Pos3:   MOV     A, R0          ; Display 1 second
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