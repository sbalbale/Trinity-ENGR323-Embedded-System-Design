ORG     0000h           
            AJMP    MAIN           

            ORG     0013h          ; External Interrupt 1 vector
            AJMP    EXT1_ISR           

            ORG     000Bh          ; Timer 0 vector
            AJMP    Timer0_ISR

            ORG     0100h          
MAIN:       MOV     SP, #30h       
            MOV     TMOD, #01h     ; Timer 0, mode 1 (16-bit)

            ; Initialize registers
            MOV     R0, #00h      ; Display digit 0 (units)
            MOV     R1, #00h      ; Display digit 1 (tens)
            MOV     R2, #00h      ; Display digit 2 (hundreds)
            MOV     R3, #00h      ; Display digit 3 (thousands)
            MOV     R4, #00h      ; Display position
            
            ; Timer counter (24-bit: 22h:21h:20h)
            MOV     20h, #00h     ; Timer counter low byte
            MOV     21h, #00h     ; Timer counter middle byte
            MOV     22h, #00h     ; Timer counter high byte
            
            MOV     23h, #01h     ; First calculation flag (1=first press)
            MOV     24h, #00h     ; Status flags
            
            ; Setup P3.3 as input for INT1
            SETB    P3.3          ; Set P3.3 (INT1) as input with pull-up
            
            ; Setup External Interrupt 1
            SETB    IT1           ; Falling edge triggered
            SETB    EX1           ; Enable INT1
            CLR     IE1           ; Clear any pending interrupt flag
            
            ; Set interrupt priority (optional)
            SETB    IP.2          ; Give INT1 high priority
            
            ; Timer 0 setup for 5ms (12 MHz clock)
            MOV     TH0, #0ECh     
            MOV     TL0, #078h
            SETB    ET0           ; Enable Timer 0
            SETB    EA            ; Enable global interrupts
            SETB    TR0           ; Start Timer 0

            ; Initial display shows "0000"
            MOV     R0, #00h
            MOV     R1, #00h
            MOV     R2, #00h
            MOV     R3, #00h

MainLoop:   SJMP    MainLoop      ; Everything handled by interrupts

; Timer 0 ISR - Handles display refresh and time counting
Timer0_ISR: PUSH    ACC            
            PUSH    PSW

            ; Reload timer for next 5ms
            CLR     TR0            
            MOV     TH0, #0ECh     
            MOV     TL0, #078h     
            SETB    TR0            


            ; Increment time counter if not the first press
            MOV     A, 23h
            JNZ     Skip_Count     ; Skip if it's the first press

            ; Increment 24-bit counter (22h:21h:20h)
            INC     20h
            MOV     A, 20h
            JNZ     Skip_Inc1
            INC     21h            ; Increment middle byte on overflow
Skip_Inc1:  MOV     A, 21h
            JNZ     Skip_Inc2
            INC     22h            ; Increment high byte on overflow
Skip_Inc2:

Skip_Count:
            ; Handle display multiplexing
            MOV     A, R4          ; Get current display position
            
            CJNE    A, #00h, Pos1
            MOV     A, R0          ; Units digit
            ORL     A, #30h        ; Position 3 code (rightmost)
            SJMP    Output_Digit

Pos1:       CJNE    A, #01h, Pos2
            MOV     A, R1          ; Tens digit
            ORL     A, #20h        ; Position 2 code
            SJMP    Output_Digit

Pos2:       CJNE    A, #02h, Pos3
            MOV     A, R2          ; Hundreds digit
            ORL     A, #10h        ; Position 1 code
            SJMP    Output_Digit

Pos3:       MOV     A, R3          ; Thousands digit
            ORL     A, #00h        ; Position 0 code (leftmost)

Output_Digit:
            MOV     P1, A          ; Output to display

            ; Update display position
            MOV     A, R4
            INC     A              
            CJNE    A, #04h, Save_Pos
            MOV     A, #00h        
Save_Pos:   MOV     R4, A         

            POP     PSW
            POP     ACC
            RETI

; External Interrupt 1 ISR - Calculate CPM on button press
EXT1_ISR:   PUSH    ACC
            PUSH    PSW
            PUSH    B
            PUSH    DPH
            PUSH    DPL
            
            CLR     IE1           ; Clear the interrupt flag
            
            ; Add a short debounce delay
            MOV     B, #50
EXT1_Delay: DJNZ    B, EXT1_Delay

            ; Check if this is the first press
            MOV     A, 23h
            JZ      Calculate_CPM
            
            ; First press - just start the timer and clear flag
            MOV     23h, #00h     ; Clear first press flag
            MOV     20h, #00h     ; Reset counter low byte
            MOV     21h, #00h     ; Reset counter middle byte
            MOV     22h, #00h     ; Reset counter high byte
            LJMP    EXT1_Exit     ; Use SJMP instead of LJMP for short jump

Calculate_CPM:
            ; Calculate CPM = 12000 / timer_count
            ; Check if count is very small (prevent division by zero or very high results)
            MOV     A, 20h
            ORL     A, 21h
            ORL     A, 22h
            JNZ     Valid_Count
            
            ; If count is 0, show maximum CPM (9999)
            MOV     R3, #9        ; Thousands
            MOV     R2, #9        ; Hundreds
            MOV     R1, #9        ; Tens
            MOV     R0, #9        ; Units
            LJMP    Reset_Timer   ; Use SJMP instead of LJMP

Valid_Count:
            ; Check if count is too large (> 12000 ticks = 60 seconds)
            MOV     A, 22h        ; High byte
            JNZ     Min_CPM       ; If high byte not 0, time > 1.3 minutes
            
            MOV     A, 21h        ; Middle byte
            CJNE    A, #46, Check_Middle  ; 46 * 256 = 11776
Check_Middle:
            JC      Normal_CPM    ; If middle byte < 46, proceed with calculation
            JNZ     Check_Exact   ; If middle byte > 46, check exact boundary

            ; Middle byte = 46, check low byte
            MOV     A, 20h
            CJNE    A, #224, Check_Low  ; 46*256 + 224 = 12000
Check_Low:
            JC      Normal_CPM    ; If time < 60 seconds (12000 ticks), calculate

Min_CPM:    ; Time >= 60 seconds, show minimum CPM (60)
            MOV     R3, #0        ; Thousands
            MOV     R2, #0        ; Hundreds  
            MOV     R1, #6        ; Tens
            MOV     R0, #0        ; Units
            LJMP    Reset_Timer

Check_Exact:
            JNC     Min_CPM       ; If middle byte > 46, show min CPM

Normal_CPM:
            ; Calculate 12000 / timer_count using LFSR approach
            ; Load 24-bit timer count into B:DPH:DPL
            MOV     DPL, 20h      ; Low byte
            MOV     DPH, 21h      ; Middle byte
            MOV     B, 22h        ; High byte (should be 0 for normal calculations)

            ; Simple division method:
            ; Set up dividend (12000 = 0x2EE0)
            MOV     30h, #0E0h    ; Low byte of 12000
            MOV     31h, #2Eh     ; High byte of 12000
            MOV     32h, #00h     ; Extended precision
            
            ; Zero out the result
            MOV     33h, #00h     ; Result low byte
            MOV     34h, #00h     ; Result high byte
            
            ; Division loop (12000 / timer_count)
            MOV     R7, #16       ; 16-bit division
            
Div_Loop:   ; Left shift the result
            CLR     C
            MOV     A, 33h
            RLC     A
            MOV     33h, A
            MOV     A, 34h
            RLC     A
            MOV     34h, A
            
            ; Left shift the dividend
            CLR     C
            MOV     A, 30h
            RLC     A
            MOV     30h, A
            MOV     A, 31h
            RLC     A
            MOV     31h, A
            MOV     A, 32h
            RLC     A
            MOV     32h, A
            
            ; Check if dividend >= divisor
            CLR     C
            MOV     A, 30h
            SUBB    A, DPL
            MOV     35h, A        ; Store remainder low
            MOV     A, 31h
            SUBB    A, DPH
            MOV     36h, A        ; Store remainder middle
            MOV     A, 32h
            SUBB    A, B
            JC      Skip_Sub      ; If dividend < divisor, skip
            
            ; Dividend >= divisor, update dividend and set result bit
            MOV     30h, 35h      ; Update dividend with remainder
            MOV     31h, 36h
            MOV     32h, A
            INC     33h           ; Set bit 0 of result
            
Skip_Sub:   
            DJNZ    R7, Div_Loop  ; Continue for all 16 bits
            
            ; Result is now in 34h:33h
            MOV     A, 34h
            MOV     B, #10
            DIV     AB            ; A = thousands, B = hundreds
            MOV     R3, A
            MOV     R2, B
            
            MOV     A, 33h
            MOV     B, #10
            DIV     AB            ; A = tens, B = units
            MOV     R1, A
            MOV     R0, B

Reset_Timer:
            ; Reset the timer for the next interval
            MOV     20h, #00h
            MOV     21h, #00h
            MOV     22h, #00h
            MOV     23h, #01h     ; CRITICAL FIX: Reset first calculation flag for next measurement
            
            ; Ensure External Interrupt 1 is properly enabled
            SETB    IT1           ; Falling edge triggered
            SETB    EX1           ; Enable INT1
            CLR     IE1           ; Clear any pending interrupt
            SETB    EA            ; Ensure global interrupts are enabled

EXT1_Exit:  
            ; Add a small delay before returning to avoid switch bouncing
            MOV     B, #200       ; Longer debounce delay after processing
EXT1_Exit_Delay: 
            DJNZ    B, EXT1_Exit_Delay
            
            POP     DPL
            POP     DPH
            POP     B
            POP     PSW
            POP     ACC
            RETI

            END