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
            MOV     27h, #00h     ; New: Overflow counter for long intervals (>1.275s)
            MOV     28h, #00h     ; New: Total overflow for averaging
            
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
            
            ; Check if time counter overflows
            MOV     A, 21h
            JNZ     Display_Update ; If not zero, no overflow
            INC     27h           ; Increment overflow counter when 21h rolls over to 0

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
            MOV     27h, #00h     ; Clear overflow counter
            MOV     28h, #00h     ; Clear total overflow
            LJMP    EXT0_ISR_Exit
            
Handle_Subsequent_Click:
            ; This is a subsequent click
            
            ; First, check if time is too small to prevent errors
            MOV     A, 21h
            CJNE    A, #12, Check_Overflow  ; 12 * 5ms = 60ms minimum (avoid impossibly fast rates)
            JC      Too_Fast      ; If less than 12 (carry set), click too fast

Check_Overflow:
            ; Check if we have any overflow counts
            MOV     A, 27h
            JNZ     Valid_Time    ; If overflow count > 0, time is definitely valid
            
            ; No overflow, check if base time count is valid
            MOV     A, 21h
            CJNE    A, #12, Valid_Time_Check
            JC      Too_Fast      ; If less than 12, too fast
            SJMP    Valid_Time
            
Valid_Time_Check:
            JNC     Valid_Time    ; If ≥ 12, time is valid
            
Too_Fast:   
            MOV     20h, #01h     ; Reset to first-click state if click too fast
            MOV     21h, #00h     ; Reset counter
            MOV     27h, #00h     ; Reset overflow counter
            LJMP    EXT0_ISR_Exit
            
Valid_Time:
            ; Add this interval to total time
            MOV     A, 22h
            ADD     A, 21h
            MOV     22h, A
            
            ; Add overflow to total overflow
            MOV     A, 28h
            ADD     A, 27h
            MOV     28h, A
            
            ; Increment click count
            INC     23h
            
            ; Check if we have enough clicks for averaging
            MOV     A, 23h
            CJNE    A, 26h, Not_Enough_Clicks
            
            ; We have enough clicks to calculate average
            
            ; If we have overflow, use extended calculation
            MOV     A, 28h
            JNZ     Extended_Calculation
            
            ; Standard calculation (no overflow)
            MOV     A, 22h
            MOV     B, 23h
            DIV     AB            ; A = average interval
            
            ; Now calculate BPM = 12000 / average_interval
            MOV     24h, #120     ; Low byte of 12000
            MOV     25h, #47      ; High byte of 12000 (actually 12120 for easier calculation)
            MOV     B, A          ; B = average interval
            LJMP    Calculate_BPM
            
			
Not_Enough_Clicks:
            ; Check if we have overflow for this single click
            MOV     A, 27h
            JNZ     Extended_Single_Calculation
            
            ; Standard calculation for single click (no overflow)
            ; Calculate BPM based on current interval
            MOV     24h, #120     ; Low byte of 12000
            MOV     25h, #47      ; High byte of 12000
            MOV     B, 21h        ; B = current interval
            LJMP    Calculate_BPM
		
            
Check_Moderate_Overflow:
            ; For moderate overflows, use more accurate calculation
            ; Each overflow is 255 units of 5ms = 1.275 seconds
            ; We use formula: BPM = 60000 / ((overflow * 1275) + (remaining_count * 5))
            
            ; First, calculate (overflow * 1275)
            MOV     A, 28h        ; Load overflow count
            MOV     B, #255       ; Multiply by 255 (using 5 * 255 = 1275)
            MUL     AB            ; Result in B:A
            MOV     24h, A        ; Store low byte of result
            MOV     25h, B        ; Store high byte of result
            
            ; Now multiply by 5 to get 1275 * overflow
            MOV     A, 24h
            MOV     B, #5
            MUL     AB            ; Result in B:A
            MOV     24h, A        ; Store low byte
            MOV     R7, B         ; Store high byte temporarily
            
            MOV     A, 25h
            MOV     B, #5
            MUL     AB            ; Result in B:A
            ADD     A, R7         ; Add carried high byte from previous multiply
            MOV     25h, A        ; Store middle byte
            MOV     R7, B         ; Store highest byte
            
            ; Now add (remaining_count * 5)
            MOV     A, 22h        ; Load remaining time count
            MOV     B, #5
            MUL     AB            ; Result in B:A
            ADD     A, 24h        ; Add to low byte of result
            MOV     24h, A
            MOV     A, B          ; Get high byte of multiply
            ADDC    A, 25h        ; Add with carry to middle byte
            MOV     25h, A
            MOV     A, #0
            ADDC    A, R7         ; Add carry to highest byte
            MOV     R7, A         ; R7 now holds highest byte
            
            ; Now we have total_time_in_ms in R7:25h:24h
            ; We need to divide 60000 by this value
            ; Use a simplified approach based on the magnitude
            
            ; Check if the total time is very large (highest byte > 0)
            MOV     A, R7
            JZ      Moderate_Time
            
            ; Very large time - BPM is likely < 10
            ; Just display a low BPM
            MOV     R3, #0        ; Thousands = 0
            MOV     R2, #0        ; Hundreds = 0
            MOV     R1, #0        ; Tens = 0
            MOV     R0, #8        ; Ones = 8 (arbitrary low value)
            LJMP    Reset_For_Next
			
Extended_Calculation:
            ; For low heart rates with overflow
            ; First check if overflow is very large (indicating extremely slow rate)
            MOV     A, 28h
            CJNE    A, #20, Check_Moderate_Overflow  ; 20 overflows = ~5 seconds
            JC      Check_Moderate_Overflow          ; If < 20, continue
            
            ; Very low heart rate (< 12 BPM), just set to minimum displayable
            MOV     R3, #0        ; Thousands = 0
            MOV     R2, #0        ; Hundreds = 0
            MOV     R1, #1        ; Tens = 1
            MOV     R0, #0        ; Ones = 0
            LJMP    Reset_For_Next
            
Extended_Single_Calculation:
            ; Handle single click with overflow
            ; Check if overflow is very large (indicating extremely slow rate)
            CJNE    A, #20, Check_Moderate_Single  ; 20 overflows = ~5 seconds
            JC      Check_Moderate_Single          ; If < 20, continue
            
            ; Very low heart rate (< 12 BPM), just set to minimum displayable
            MOV     R3, #0        ; Thousands = 0
            MOV     R2, #0        ; Hundreds = 0
            MOV     R1, #1        ; Tens = 1
            MOV     R0, #0        ; Ones = 0
            LJMP    Reset_For_Next
			
Moderate_Time:
            ; Check if middle byte is large
            MOV     A, 25h
            JZ      Small_Time
            CJNE    A, #4, Check_Med_Range
            JC      Med_Range     ; If < 4, medium range
            
            ; Large middle byte - very low BPM
            MOV     R3, #0
            MOV     R2, #0
            MOV     R1, #1
            MOV     R0, #5        ; Display 15 BPM
            LJMP    Reset_For_Next
            
Check_Med_Range:
            JNC     Large_Med_Range ; If >= 4, also low range
            
Med_Range:  ; Middle byte between 1-3, BPM around 20-40
            MOV     A, #30        ; Approximate BPM value
            MOV     B, 25h        ; Divide by middle byte for rough estimate
            DIV     AB
            MOV     B, #10
            DIV     AB
            MOV     R1, A         ; Tens digit
            MOV     R0, B         ; Ones digit
            MOV     R2, #0        ; Hundreds = 0
            MOV     R3, #0        ; Thousands = 0
            LJMP    Reset_For_Next
            
Large_Med_Range:
            ; Middle byte between 4-255, very low BPM
            MOV     R3, #0
            MOV     R2, #0
            MOV     R1, #1        ; Tens = 1
            MOV     R0, #2        ; Ones = 2
            LJMP    Reset_For_Next
            
Small_Time:
            ; Only low byte is significant, can do better calculation
            ; BPM ≈ 300 / low_byte for single overflow cases
            MOV     A, #250       ; Use 250 as constant instead of 300 (better approximation)
            MOV     B, 24h
            DIV     AB
            
            ; Convert result to BCD for display
            MOV     B, #10
            DIV     AB
            MOV     R1, A         ; Tens digit
            MOV     R0, B         ; Ones digit
            MOV     R2, #0        ; Hundreds digit
            MOV     R3, #0        ; Thousands digit
            
            SJMP    Reset_For_Next
            
Check_Moderate_Single:
            ; Similar improved calculation for single clicks with overflow
            ; Using approximation formula based on overflow magnitude
            
            ; First check if overflow is large
            CJNE    A, #4, Check_Single_Med
            JC      Single_Med    ; If < 4, medium range
            
            ; Large overflow - very low BPM
            MOV     R3, #0
            MOV     R2, #0
            MOV     R1, #1
            MOV     R0, #5        ; Display 15 BPM
            SJMP    Reset_For_Next
            
Check_Single_Med:
            JNC     Single_Large_Med ; If >= 4, also low range
            
Single_Med: ; Overflow between 1-3, BPM around 20-40
            MOV     A, #30        ; Approximate BPM value
            MOV     B, 27h        ; Divide by overflow count for rough estimate
            DIV     AB
            MOV     B, #10
            DIV     AB
            MOV     R1, A         ; Tens digit
            MOV     R0, B         ; Ones digit
            MOV     R2, #0        ; Hundreds = 0
            MOV     R3, #0        ; Thousands = 0
            SJMP    Reset_For_Next
            
Single_Large_Med:
            ; Overflow between 4-255, very low BPM
            MOV     R3, #0
            MOV     R2, #0
            MOV     R1, #1        ; Tens = 1
            MOV     R0, #2        ; Ones = 2
            SJMP    Reset_For_Next
            
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
            
Reset_For_Next:
            ; Reset for next measurement
            MOV     21h, #00h     ; Reset interval timer for next click
            MOV     27h, #00h     ; Reset overflow counter
            
            ; If we've reached our desired clicks for average, reset the averaging
            MOV     A, 23h
            CJNE    A, 26h, EXT0_ISR_Exit
            MOV     22h, #00h     ; Reset total time
            MOV     23h, #00h     ; Reset click count
            MOV     28h, #00h     ; Reset total overflow

EXT0_ISR_Exit:
            POP     PSW
            POP     ACC
            RETI

            END