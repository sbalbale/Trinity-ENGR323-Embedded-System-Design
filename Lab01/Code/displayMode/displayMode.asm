            ORG     0000h           
            AJMP    MAIN           

            ORG     0013h          ; External Interrupt 1 vector
            AJMP    EXT1_ISR           

            ORG     000Bh          ; Timer 0 vector
            AJMP    Timer0_ISR

            ORG     0030h          
MAIN:       MOV     SP, #30h       
            MOV     TMOD, #01h     ; Timer 0, mode 1 (16-bit)

            ; Initialize registers
            MOV     R4, #00h      ; Display position
            MOV     20h, #00h     ; Mode (0-3)
            
            ; Setup External Interrupt 1
            SETB    IT1           ; Falling edge triggered
            SETB    EX1           ; Enable INT1
            
            ; Enable display refresh timer
            SETB    ET0           ; Enable Timer 0
            SETB    EA            ; Enable global interrupts
            SETB    TR0           ; Start Timer 0

MainLoop:   SJMP    MainLoop       ; Everything handled by interrupts

; External Interrupt 1 ISR - Toggle modes
EXT1_ISR:   PUSH    ACC
            PUSH    PSW
            
            MOV     A, 20h         ; Get current mode
            INC     A              ; Next mode
            CJNE    A, #04h, Save_Mode
            MOV     A, #00h        ; Wrap to mode 0
Save_Mode:  MOV     20h, A         ; Save new mode
            
            POP     PSW
            POP     ACC
            RETI

; Timer 0 ISR - Display refresh
Timer0_ISR: PUSH    ACC            
            PUSH    PSW

            ; Reload timer for 5ms
            MOV     TH0, #0ECh     
            MOV     TL0, #0BDh     
            
            ; Display current mode
            MOV     A, R4          ; Get display position
            JZ      ShowMode       ; If position 0, show mode
            
            ; Other positions blank
            MOV     A, #0FFh       ; Turn off display
            SJMP    Output

ShowMode:   MOV     A, 20h         ; Get current mode
            
Output:     MOV     P1, A          ; Update display

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