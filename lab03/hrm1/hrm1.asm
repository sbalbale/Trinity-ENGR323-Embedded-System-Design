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
            MOV     R0, #00h      ; Ones digit of heart rate
            MOV     R1, #00h      ; Tens digit of heart rate
            MOV     R2, #00h      ; Hundreds digit of heart rate
            MOV     R3, #00h      ; Thousands digit of heart rate
            MOV     R4, #00h      ; Display position
            MOV     R5, #00h      ; Counter for 5ms intervals
            
            ; Initialize variables
            MOV     20h, #00h     ; State (0=No clicks, 1=First click received, 2+=Subsequent clicks)
            MOV     21h, #00h     ; Time count (5ms intervals between clicks)
            MOV     22h, #00h     ; Total time for averaging
            MOV     23h, #00h     ; Click count (for averaging)
            MOV     24h, #00h     ; Temporary storage during calculation
            MOV     25h, #00h     ; Temporary storage during calculation
            MOV     26h, #03h     ; Number of clicks to average (configurable: 2 or 3)
            
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

            ; Check if we're in timing mode
            MOV     A, 20h
            JZ      Display_Update  ; If 0, we're not timing yet
            
            ; We're timing between clicks
            INC     21h           ; Increment the time counter

Display_Update:
            ; Display logic
            MOV     A, R4          
            CJNE    A, #00h, Pos1
            MOV     A, R3         ; Thousands digit
            SJMP    Output_Digit

Pos1:       CJNE    A, #01h, Pos2
            MOV     A, R2         ; Hundreds digit
            ORL     A, #10h        
            SJMP    Output_Digit

Pos2:       CJNE    A, #02h, Pos3
            MOV     A, R1         ; Tens digit
            ORL     A, #20h        
            SJMP    Output_Digit

Pos3:       MOV     A, R0         ; Ones digit
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
            
            ; Check current state
            MOV     A, 20h
            JNZ     Handle_Subsequent_Click  ; If not 0, we've had clicks before
            
            ; First click ever - just start timing
            MOV     20h, #01h     ; Set to "first click received" state
            MOV     21h, #00h     ; Reset time counter
            MOV     22h, #00h     ; Clear total time
            MOV     23h, #00h     ; Clear click count
            SJMP    EXT0_ISR_Exit
            
Handle_Subsequent_Click:
            ; This is a subsequent click
            
            ; First, check if time is too small to prevent errors
            MOV     A, 21h
            CJNE    A, #12, Valid_Time  ; 12 * 5ms = 60ms minimum (avoid impossibly fast rates)
            MOV     20h, #01h     ; Reset to first-click state if click too fast
            MOV     21h, #00h     ; Reset counter
            SJMP    EXT0_ISR_Exit
            
Valid_Time:
            JC      EXT0_ISR_Exit  ; If less than 12 (carry set), click too fast - ignore
            
            ; Add this interval to total time
            MOV     A, 22h
            ADD     A, 21h
            MOV     22h, A
            
            ; Increment click count
            INC     23h
            
            ; Check if we have enough clicks for averaging
            MOV     A, 23h
            CJNE    A, 26h, Not_Enough_Clicks
            
            ; We have enough clicks to calculate average
            
            ; Calculate average interval: 22h / 23h (total time / click count)
            MOV     A, 22h
            MOV     B, 23h
            DIV     AB            ; A = average interval
            
            ; Now calculate BPM = 12000 / average_interval
            MOV     24h, #120     ; Low byte of 12000
            MOV     25h, #47      ; High byte of 12000 (actually 12120 for easier calculation)
            MOV     B, A          ; B = average interval
            SJMP    Calculate_BPM
            
Not_Enough_Clicks:
            ; Calculate BPM based on current interval
            MOV     24h, #120     ; Low byte of 12000
            MOV     25h, #47      ; High byte of 12000
            MOV     B, 21h        ; B = current interval
            
Calculate_BPM:
            ; Using repeated subtraction to simulate division
            ; Calculate 12000 / B
            MOV     22h, #0       ; Initialize result quotient
            MOV     23h, #0       ; Initialize hundreds place
            
DivLoop:
            ; Check if we can subtract B from 25h:24h
            CLR     C
            MOV     A, 24h
            SUBB    A, B
            MOV     24h, A        ; Store result back
            
            MOV     A, 25h
            SUBB    A, #0         ; Subtract borrow
            MOV     25h, A
            
            JC      EndDiv        ; If carry, we're done
            
            ; Increment result
            INC     22h
            MOV     A, 22h
            CJNE    A, #100, DivLoop   ; Keep going until quotient reaches 100
            MOV     22h, #0            ; Reset quotient to 0
            INC     23h                ; Increment hundreds place
            SJMP    DivLoop
            
EndDiv:
            ; Now convert result to BCD for display
            MOV     A, 22h        ; Get quotient (0-99 portion)
            MOV     B, #10
            DIV     AB
            MOV     R1, A         ; Tens digit
            MOV     R0, B         ; Ones digit
            
            ; Handle hundreds place
            MOV     A, 23h
            MOV     R2, A         ; Hundreds digit
            MOV     R3, #0        ; Thousands digit
            
            ; Reset for next measurement
            MOV     21h, #00h     ; Reset interval timer for next click
            
            ; If we've reached our desired clicks for average, reset the averaging
            MOV     A, 23h
            CJNE    A, 26h, EXT0_ISR_Exit
            MOV     22h, #00h     ; Reset total time
            MOV     23h, #00h     ; Reset click count

EXT0_ISR_Exit:
            POP     PSW
            POP     ACC
            RETI

            END