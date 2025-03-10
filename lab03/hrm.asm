ORG     0000h           
            AJMP    MAIN           

            ORG     0013h          ; External Interrupt 1 vector
            AJMP    EXT1_ISR           

            ORG     000Bh          ; Timer 0 vector
            AJMP    Timer0_ISR

            ORG     0100h          
MAIN:       MOV     SP, #30h       
            MOV     TMOD, #11h     ; Timer 0: mode 1 (16-bit), Timer 1: mode 1 (16-bit)

            ; Initialize heart rate registers (Bank 0)
            CLR     RS0            ; Select Bank 0
            CLR     RS1
            MOV     R0, #00h      ; BPM ones digit
            MOV     R1, #00h      ; BPM tens digit
            MOV     R2, #00h      ; BPM hundreds digit
            MOV     R3, #00h      ; Reserved (not used)
            MOV     R4, #00h      ; Display position
            MOV     R5, #00h      ; Counter for 5ms intervals
            MOV     R6, #00h      ; Display mode
            
            ; Heart rate calculation variables (Bank 1)
            SETB    RS0            ; Select Bank 1
            CLR     RS1
            MOV     R0, #00h      ; Last beat time (low byte)
            MOV     R1, #00h      ; Last beat time (high byte)
            MOV     R2, #00h      ; Beat interval (low byte)
            MOV     R3, #00h      ; Beat interval (high byte)
            MOV     R4, #00h      ; Beat counter
            MOV     R5, #00h      ; Average interval (low byte)
            MOV     R6, #00h      ; Average interval (high byte)
            MOV     R7, #00h      ; Heart rate (BPM)
            
            ; Additional storage (Bank 2)
            CLR     RS0
            SETB    RS1
            MOV     R0, #00h      ; Time without beats counter (low byte)
            MOV     R1, #00h      ; Time without beats counter (high byte)
            
            ; Return to Bank 0 for main program
            CLR     RS0
            CLR     RS1
            
            ; Setup External Interrupt 1
            SETB    IT1           ; Falling edge triggered
            SETB    EX1           ; Enable INT1
            
            ; Timer 0 setup for 5ms display refresh
            MOV     TH0, #0ECh     
            MOV     TL0, #078h
            SETB    ET0           ; Enable Timer 0 interrupt
            
            ; Timer 1 setup as time counter
            MOV     TH1, #00h
            MOV     TL1, #00h
            SETB    TR1           ; Start Timer 1
            
            SETB    EA            ; Enable global interrupts
            SETB    TR0           ; Start Timer 0

; Main loop - everything handled by interrupts
MainLoop:   
            ; Check for inactive period (3 seconds without beats)
            ; Switch to Bank 2 to check timeout counters
            CLR     RS0
            SETB    RS1
            MOV     A, R1         ; Time without beats counter (high byte)
            JNZ     Check_Reset
            MOV     A, R0         ; Time without beats counter (low byte)
            CJNE    A, #150, Skip_Reset  ; 150 × 20ms = 3 seconds

Check_Reset:
            ; Reset heart rate to 0
            ; Update Bank 1 heart rate
            SETB    RS0
            CLR     RS1
            MOV     R7, #00h      ; Heart rate (BPM) = 0
            
            ; Update Bank 0 display digits
            CLR     RS0
            CLR     RS1
            MOV     R0, #00h      ; BPM ones digit
            MOV     R1, #00h      ; BPM tens digit
            MOV     R2, #00h      ; BPM hundreds digit
            
            ; Reset timeout counters in Bank 2
            CLR     RS0
            SETB    RS1
            MOV     R0, #00h      ; Time without beats low byte
            MOV     R1, #00h      ; Time without beats high byte
            
            ; Return to Bank 0
            CLR     RS0
            CLR     RS1
            
Skip_Reset: CLR     RS0            ; Ensure back to Bank 0
            CLR     RS1
            SJMP    MainLoop

Timer0_ISR: PUSH    ACC
            PUSH    PSW

            ; Reload timer for next 5ms
            CLR     TR0
            MOV     TH0, #0ECh
            MOV     TL0, #078h
            CLR     TF0
            SETB    TR0

            ; Update heart rate calculation every 4 ticks (20ms)
            INC     R5
            MOV     A, R5
            CJNE    A, #04h, Display_Update
            MOV     R5, #00h

            ; Update timeout counter if no beats (Bank 2)
            CLR     RS0
            SETB    RS1
            MOV     A, R0         ; Time without beats (low byte)
            ADD     A, #01h
            MOV     R0, A
            MOV     A, R1         ; Time without beats (high byte)
            ADDC    A, #00h
            MOV     R1, A
            
            ; Return to Bank 0 for display update
            CLR     RS0
            CLR     RS1

Display_Update:
            ; Select digit position to display
            MOV     A, R4
            CJNE    A, #00h, Try_Pos1
            MOV     A, R2          ; Hundreds digit
            ORL     A, #00h        ; Position 0
            SJMP    Output_Digit

Try_Pos1:   CJNE    A, #01h, Try_Pos2
            MOV     A, R1          ; Tens digit
            ORL     A, #10h        ; Position 1
            SJMP    Output_Digit

Try_Pos2:   CJNE    A, #02h, Try_Pos3
            MOV     A, R0          ; Ones digit
            ORL     A, #20h        ; Position 2
            SJMP    Output_Digit

Try_Pos3:   MOV     A, #0Bh        ; Display 'b' for BPM
            ORL     A, #30h        ; Position 3

Output_Digit:
            MOV     P1, A          ; Output to display

            ; Update display position for next time
            MOV     A, R4
            INC     A
            CJNE    A, #04h, Save_Pos
            MOV     A, #00h
Save_Pos:   MOV     R4, A

            POP     PSW
            POP     ACC
            RETI

; External Interrupt 1 ISR - Heartbeat detected
EXT1_ISR:   PUSH    ACC
            PUSH    PSW
            PUSH    B
            
            ; Reset timeout counter (Bank 2)
            CLR     RS0
            SETB    RS1
            MOV     R0, #00h      ; Time without beats (low byte)
            MOV     R1, #00h      ; Time without beats (high byte)
            
            ; Switch to Bank 1 for heart rate calculations
            SETB    RS0
            CLR     RS1
            
            ; Increment beat counter
            INC     R4            ; Beat counter
            
            ; Get current time from Timer 1
            MOV     A, TL1
            MOV     B, TH1
            
            ; Calculate interval since last beat
            CLR     C
            SUBB    A, R0         ; Subtract last beat time (low byte)
            MOV     R2, A         ; Store interval low byte
            MOV     A, B
            SUBB    A, R1         ; Subtract last beat time (high byte)
            MOV     R3, A         ; Store interval high byte
            
            ; Save current time as last beat time
            MOV     R0, TL1
            MOV     R1, TH1
            
            ; Only use intervals if beat counter > 1 (need at least 2 beats)
            MOV     A, R4         ; Beat counter
            CJNE    A, #02h, Skip_Calc
            
            ; For second beat, initialize average with first interval
            MOV     A, R2         ; Beat interval (low byte)
            MOV     R5, A         ; Average interval low byte
            MOV     A, R3         ; Beat interval (high byte)
            MOV     R6, A         ; Average interval high byte
            SJMP    Skip_Calc
            
Skip_Calc:  
            CJNE    A, #02h, Calculate_Average
            SJMP    Calculate_Rate
            
Calculate_Average:
            ; Switch to Bank 3 for temporary calculations
            SETB    RS0
            SETB    RS1
            
            ; For subsequent beats, update running average (75% old, 25% new)
            ; Shift average right twice (divide by 4)
            ; Copy values from Bank 1 to work with
            CLR     RS1           ; Select Bank 1
            MOV     A, R5         ; Load average interval (low byte)
            SETB    RS1           ; Back to Bank 3
            
            CLR     C
            RRC     A
            CLR     C
            RRC     A
            MOV     R0, A         ; Bank 3 R0 = average/4 (low byte)
            
            CLR     RS1           ; Select Bank 1
            MOV     A, R6         ; Load average interval (high byte)
            SETB    RS1           ; Back to Bank 3
            
            RRC     A
            RRC     A
            MOV     R1, A         ; Bank 3 R1 = average/4 (high byte)
            
            ; Shift average right once more (divide by 2)
            CLR     RS1           ; Select Bank 1
            MOV     A, R5         ; Load average interval (low byte)
            SETB    RS1           ; Back to Bank 3
            
            CLR     C
            RRC     A
            MOV     R2, A         ; Bank 3 R2 = average/2 (low byte)
            
            CLR     RS1           ; Select Bank 1
            MOV     A, R6         ; Load average interval (high byte)
            SETB    RS1           ; Back to Bank 3
            
            RRC     A
            MOV     R3, A         ; Bank 3 R3 = average/2 (high byte)
            
            ; New interval / 4
            CLR     RS1           ; Select Bank 1
            MOV     A, R2         ; Load beat interval (low byte)
            SETB    RS1           ; Back to Bank 3
            
            CLR     C
            RRC     A
            CLR     C
            RRC     A
            MOV     R4, A         ; Bank 3 R4 = interval/4 (low byte)
            
            CLR     RS1           ; Select Bank 1
            MOV     A, R3         ; Load beat interval (high byte)
            SETB    RS1           ; Back to Bank 3
            
            RRC     A
            RRC     A
            MOV     R5, A         ; Bank 3 R5 = interval/4 (high byte)
            
            ; Calculate new average = 3/4*old + 1/4*new
            ; = old/2 + old/4 + new/4
            CLR     C
            MOV     A, R0         ; A = old/4 (low byte)
            ADD     A, R2         ; Add old/2 (low byte)
            ADD     A, R4         ; Add new/4 (low byte)
            MOV     R6, A         ; Bank 3 R6 = new average (low byte)
            
            MOV     A, R1         ; A = old/4 (high byte)
            ADDC    A, R3         ; Add old/2 (high byte)
            ADDC    A, R5         ; Add new/4 (high byte)
            MOV     R7, A         ; Bank 3 R7 = new average (high byte)
            
            ; Copy results back to Bank 1
            MOV     A, R6         ; Get new average (low byte)
            CLR     RS1           ; Select Bank 1
            MOV     R5, A         ; Store in Bank 1 R5
            
            SETB    RS1           ; Select Bank 3
            MOV     A, R7         ; Get new average (high byte)
            CLR     RS1           ; Select Bank 1
            MOV     R6, A         ; Store in Bank 1 R6

Calculate_Rate:
            ; Get average interval or current interval if no average yet
            MOV     A, R4         ; Beat counter
            CJNE    A, #01h, Use_Average
            
            ; Switch to Bank 3 for calculations
            SETB    RS1
            
            ; Use current interval for first beat
            CLR     RS1           ; Select Bank 1
            MOV     A, R2         ; Get beat interval (low byte)
            SETB    RS1           ; Select Bank 3
            MOV     R0, A         ; Store in Bank 3 R0
            
            CLR     RS1           ; Select Bank 1
            MOV     A, R3         ; Get beat interval (high byte)
            SETB    RS1           ; Select Bank 3
            MOV     R1, A         ; Store in Bank 3 R1
            
            SJMP    Calc_BPM
            
Use_Average:
            ; Switch to Bank 3 for calculations
            SETB    RS1
            
            ; Use average interval
            CLR     RS1           ; Select Bank 1
            MOV     A, R5         ; Get average interval (low byte)
            SETB    RS1           ; Select Bank 3
            MOV     R0, A         ; Store in Bank 3 R0
            
            CLR     RS1           ; Select Bank 1
            MOV     A, R6         ; Get average interval (high byte)
            SETB    RS1           ; Select Bank 3
            MOV     R1, A         ; Store in Bank 3 R1
            
Calc_BPM:
            ; Check if interval is too small (< 300ms)
            MOV     A, R1         ; Check high byte first (Bank 3)
            JNZ     Valid_Interval
            MOV     A, R0         ; Check low byte (Bank 3)
            CJNE    A, #36, Check_Small  ; 36 × 8.33ms ≈ 300ms
            JNC     Valid_Interval
            
Check_Small:
            ; Interval too small, likely noise - ignore
            SJMP    Exit_ISR
            
Valid_Interval:
            ; Check if interval is too large (> 2000ms)
            MOV     A, R1         ; Check high byte (Bank 3)
            CJNE    A, #01h, Check_Large
            JC      Calculate_BPM  ; If < 256, continue
            MOV     A, R0         ; Check low byte (Bank 3)
            CJNE    A, #0F4h, Check_Large2  ; 1*256 + 244 × 8.33ms ≈ 2000ms
            JC      Calculate_BPM
            
Check_Large: 
            MOV     A, R1         ; Check high byte (Bank 3)
            JZ      Calculate_BPM  ; If high byte is 0, continue
            
Check_Large2:
            ; Interval too large, set BPM to minimum (30)
            CLR     RS1           ; Select Bank 1
            MOV     R7, #30       ; Set BPM = 30
            SJMP    Update_Display
            
Calculate_BPM:
            ; Use Bank 3 for calculations (we're already in Bank 3)
            
            ; Simplified calculation for demo purposes
            MOV     A, R0         ; Get interval low byte (Bank 3)
            MOV     B, #200
            DIV     AB            ; A = Interval/200
            MOV     B, A          ; B = Interval/200
            
            MOV     A, #60
            MUL     AB            ; A = 60 * (Interval/200)
            
            ; Handle result being too small
            JZ      Min_Rate
            CJNE    A, #30, Check_Min_Rate
            JC      Min_Rate
            
Check_Min_Rate:
            ; Handle result being too large
            CJNE    A, #220, Check_Max_Rate
            JNC     Max_Rate
            
Check_Max_Rate:
            ; Valid BPM, store it
            CLR     RS1           ; Select Bank 1
            MOV     R7, A         ; Store BPM in Bank 1 R7
            SJMP    Update_Display
            
Min_Rate:   
            CLR     RS1           ; Select Bank 1
            MOV     R7, #30      ; Minimum BPM = 30
            SJMP    Update_Display
            
Max_Rate:
            CLR     RS1           ; Select Bank 1
            MOV     R7, #220     ; Maximum BPM = 220
            
Update_Display:
            ; Convert BPM to decimal digits
            CLR     RS1            ; Select Bank 1
            MOV     A, R7          ; Get heart rate
            
            ; Return to Bank 0 for display update
            CLR     RS0
            CLR     RS1
            
            MOV     B, #100
            DIV     AB
            MOV     R2, A         ; Hundreds digit
            
            MOV     A, B
            MOV     B, #10
            DIV     AB
            MOV     R1, A         ; Tens digit
            
            MOV     R0, B         ; Ones digit

Exit_ISR:   POP     B
            POP     PSW
            POP     ACC
            RETI

            END