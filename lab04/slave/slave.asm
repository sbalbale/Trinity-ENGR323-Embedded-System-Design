;-----------------------------------------------------------------------------
; Slave.asm (Stopwatch Display Logic Version)
;-----------------------------------------------------------------------------
; Description: Receives 64 bytes of data via UART after being addressed.
;              Stores data in RAM locations 30h-6Fh.
;              Displays "dOnE" (hex D,0,E,E) when reception complete.
;              Sequentially displays received data (00-FF as hex) at 1-sec intervals.
;              Displays " End" (hex Blank,E,E,D) after showing all data.
; Target:      Generic 8051 with Stopwatch-style P1 display hardware
; Tool chain:  Generic 8051 Assembler
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Equates - Constants and Memory Locations
;-----------------------------------------------------------------------------
MY_ADDR       EQU   05h       ; Slave's own address (must match master)
DATA_COUNT    EQU   64        ; Number of data bytes to receive (0x40)
RAM_START     EQU   30h       ; Starting RAM address for received data
RAM_END       EQU   RAM_START + DATA_COUNT - 1 ; Should be 6Fh

; Display Character Codes (Hex values for decoder on P1.0-P1.3)
CHAR_0        EQU   00h
CHAR_1        EQU   01h
CHAR_2        EQU   02h
CHAR_3        EQU   03h
CHAR_4        EQU   04h
CHAR_5        EQU   05h
CHAR_6        EQU   06h
CHAR_7        EQU   07h
CHAR_8        EQU   08h
CHAR_9        EQU   09h
CHAR_A        EQU   0Ah
CHAR_B        EQU   0Bh
CHAR_C        EQU   0Ch
CHAR_D        EQU   0Dh
CHAR_E        EQU   0Eh
CHAR_F        EQU   0Fh
CHAR_BLANK    EQU   10h       ; Code > 0Fh to signify blank (decoder dependent)
CHAR_DASH     EQU   0Eh       ; Using 'E' as a substitute for dash/initial state

; State Variables (using internal RAM locations > 20h)
STATE         EQU   20h       ; 0=Wait Addr, 1=Receiving, 2=Done, 3=Displaying Data, 4=End Display
RX_COUNT_VAR  EQU   21h       ; Counter for received bytes
RX_PTR        EQU   22h       ; Pointer (R0 used directly in ISR)
DISPLAY_POS   EQU   23h       ; 7-seg multiplex position (0-3)
DISPLAY_CHAR1 EQU   24h       ; Character CODE for Digit 1 (P1.0-3)
DISPLAY_CHAR2 EQU   25h       ; Character CODE for Digit 2 (P1.0-3)
DISPLAY_CHAR3 EQU   26h       ; Character CODE for Digit 3 (P1.0-3)
DISPLAY_CHAR4 EQU   27h       ; Character CODE for Digit 4 (P1.0-3)
DISPLAY_PTR   EQU   28h       ; Pointer for reading data back from RAM for display
DELAY_COUNT   EQU   29h       ; Counter for 1-second delay (counts Timer0 overflows)
TEMP_A        EQU   2Ah       ; Temporary storage for ACC in ISRs
TEMP_PSW      EQU   2Bh       ; Temporary storage for PSW in ISRs
TEMP_B        EQU   2Ch       ; Temporary storage for B in ISRs

;-----------------------------------------------------------------------------
; Interrupt Vector Table
;-----------------------------------------------------------------------------
            ORG   0000h       ; Reset Vector
            AJMP  MAIN

            ORG   000Bh       ; Timer 0 Overflow Vector
            AJMP  Timer0_ISR

            ORG   0023h       ; Serial Port (UART) Vector
            AJMP  UART_ISR

;-----------------------------------------------------------------------------
; Main Program
;-----------------------------------------------------------------------------
            ORG   0100h       ; Start of code memory
MAIN:
            MOV   SP, #60h    ; Initialize Stack Pointer (adjust if needed)

            ; Initialize State Variables
            MOV   STATE, #00h   ; Start in Waiting for Address state
            MOV   RX_COUNT_VAR, #00h
            MOV   DISPLAY_POS, #00h
            MOV   DELAY_COUNT, #00h
            MOV   DISPLAY_PTR, #RAM_START ; Initialize display pointer

            ; Initialize Display Characters to "----" (using CHAR_DASH code)
            MOV   DISPLAY_CHAR1, #CHAR_DASH
            MOV   DISPLAY_CHAR2, #CHAR_DASH
            MOV   DISPLAY_CHAR3, #CHAR_DASH
            MOV   DISPLAY_CHAR4, #CHAR_DASH

            ; Call Initialization Routines
            ACALL Port_Init
            ACALL Timer_Init
            ACALL UART_Init
            ACALL Interrupt_Init

MainLoop:
            SJMP  MainLoop      ; Everything is handled by interrupts

;-----------------------------------------------------------------------------
; Initialization Subroutines
;-----------------------------------------------------------------------------
Port_Init:
            ; Assume P1 is output for display (combined data/select)
            MOV   P1, #0FFh     ; Initialize P1 (direction set by HW/default, often input)
            ; If using C8051Fxxx style MCU, P1MDOUT might be needed
            ; MOV   P1MDOUT, #0FFh ; Set P1 as push-pull if needed
            RET

Timer_Init:
            ; Timer 1: Baud Rate Generator (Mode 2, 8-bit Auto-Reload)
            MOV   TMOD, #21h    ; Timer 1: Mode 2, Timer 0: Mode 1 (16-bit)
            MOV   TH1, #0FAh    ; 9600 Baud at 22.1184 MHz (match master C code)
            SETB  TR1           ; Start Timer 1

            ; Timer 0: Display Refresh & 1-Second Delay (Mode 1, 16-bit)
            ; Aim for ~5ms refresh interval => DC00h for 22.1184 MHz
            MOV   TH0, #0DCh    ; Load Timer 0 initial value High Byte
            MOV   TL0, #00h     ; Load Timer 0 initial value Low Byte
            SETB  TR0           ; Start Timer 0
            RET

UART_Init:
            MOV   SCON, #0D0h   ; Mode 3 (9-bit UART), REN=1 (Enable Receive), SM2=1 initially
            RET

Interrupt_Init:
            MOV   IE, #92h      ; EA=1, ES=1, ET0=1
            RET

;-----------------------------------------------------------------------------
; Interrupt Service Routines
;-----------------------------------------------------------------------------

; Serial Port Interrupt Service Routine (Identical to previous version)
UART_ISR:
            PUSH  ACC           ; Save registers used
            PUSH  PSW
            PUSH  DPL
            PUSH  DPH
            PUSH  B

            MOV   TEMP_A, A     ; Use temporary RAM storage
            MOV   TEMP_PSW, PSW
            MOV   TEMP_B, B

            JB    RI, UART_Receive ; Jump if Receive Interrupt occurred
            JNB   TI, UART_ISR_End ; Ignore Transmit Interrupt

            CLR   TI

UART_Receive:
            MOV   A, SCON       ; Check SM2 bit status
            JB    ACC.5, Addr_Check ; If SM2 is 1, expect address

Data_Receive:                  ; SM2 is 0, expect data
            MOV   A, SBUF        ; Read received data byte
            MOV   R0, RX_PTR     ; Load RAM pointer into R0
            MOV   @R0, A         ; Store data byte in RAM
            INC   R0             ; Increment RAM pointer
            MOV   RX_PTR, R0     ; Save updated pointer
            DJNZ  RX_COUNT_VAR, Data_Receive_End ; Decrement byte counter

            ; --- All Bytes Received ---
            MOV   STATE, #02h    ; Set state to Done
            SETB  SM2            ; Wait for next address
            MOV   DISPLAY_CHAR1, #CHAR_D ; Prepare "dOnE" display
            MOV   DISPLAY_CHAR2, #CHAR_0 ; Use 0 for O
            MOV   DISPLAY_CHAR3, #CHAR_E ; Use E for n
            MOV   DISPLAY_CHAR4, #CHAR_E
            MOV   DELAY_COUNT, #200 ; Start 1-sec delay counter (~200 * 5ms)
            SJMP  Data_Receive_End

Addr_Check:                    ; SM2 is 1, expect address
            MOV   A, SBUF        ; Read potential address
            CJNE  A, #MY_ADDR, Addr_Mismatch

            ; --- Address Matched ---
            CLR   SM2            ; Enable data reception
            MOV   STATE, #01h    ; State = Receiving Data
            MOV   RX_COUNT_VAR, #DATA_COUNT ; Init byte counter
            MOV   RX_PTR, #RAM_START ; Init RAM pointer
            SJMP  Data_Receive_End

Addr_Mismatch:                 ; Address did not match, ignore
            ; SM2 remains 1

Data_Receive_End:
            CLR   RI             ; Clear Receive Interrupt flag

UART_ISR_End:
            MOV   A, TEMP_A     ; Restore registers
            MOV   PSW, TEMP_PSW
            MOV   B, TEMP_B

            POP   B
            POP   DPH
            POP   DPL
            POP   PSW
            POP   ACC
            RETI

; Timer 0 Interrupt Service Routine (Stopwatch-style Display Logic)
Timer0_ISR:
            PUSH  ACC           ; Save registers
            PUSH  PSW
            PUSH  B

            MOV   TEMP_A, A     ; Use temporary RAM storage
            MOV   TEMP_PSW, PSW
            MOV   TEMP_B, B

            ; Reload Timer 0 for next ~5ms interval
            CLR   TR0
            MOV   TH0, #0DCh
            MOV   TL0, #00h
            SETB  TR0

            ; --- Handle States and Select Display Characters ---
            MOV   A, STATE
            CJNE  A, #02h, T0_Check_State_3 ; Check if in DONE state (2)
            ; State 2 ("dOnE"): Already set display chars in UART_ISR
            SJMP  T0_Update_Display

T0_Check_State_3:
            CJNE  A, #03h, T0_Check_State_4 ; Check if in DISPLAYING DATA state (3)
            ; State 3 (Displaying Data): Decrement delay, update display if needed
            DJNZ  DELAY_COUNT, T0_Update_Display ; If delay counter not zero, just refresh display
            ; --- 1 Second Delay Expired ---
            MOV   DELAY_COUNT, #200 ; Reload delay counter (~200 * 5ms = 1 sec)
            ACALL Display_Next_Hex_Byte ; Update display chars for next byte
            SJMP  T0_Update_Display

T0_Check_State_4:
            CJNE  A, #04h, T0_Update_Display ; Check if in END state (4)
            ; State 4 (" End"): Set display chars
            MOV   DISPLAY_CHAR1, #CHAR_BLANK ; Blank
            MOV   DISPLAY_CHAR2, #CHAR_E     ; E
            MOV   DISPLAY_CHAR3, #CHAR_E     ; n (using E)
            MOV   DISPLAY_CHAR4, #CHAR_D     ; d
            SJMP  T0_Update_Display

            ; States 0 (Wait Addr) & 1 (Receiving): Use "----" (CHAR_DASH) set at init

            ; --- Multiplex Display using Stopwatch Logic ---
T0_Update_Display:
            MOV   A, DISPLAY_POS ; Get current position (0-3)
            CJNE  A, #00h, T0_Pos1
            MOV   A, DISPLAY_CHAR1 ; Get Digit 1 char code
            ORL   A, #00h        ; OR with position code 0
            SJMP  T0_Output_Digit

T0_Pos1:    CJNE  A, #01h, T0_Pos2
            MOV   A, DISPLAY_CHAR2 ; Get Digit 2 char code
            ORL   A, #10h        ; OR with position code 1 (0001 0000)
            SJMP  T0_Output_Digit

T0_Pos2:    CJNE  A, #02h, T0_Pos3
            MOV   A, DISPLAY_CHAR3 ; Get Digit 3 char code
            ORL   A, #20h        ; OR with position code 2 (0010 0000)
            SJMP  T0_Output_Digit

T0_Pos3:    ; Position must be 3
            MOV   A, DISPLAY_CHAR4 ; Get Digit 4 char code
            ORL   A, #30h        ; OR with position code 3 (0011 0000)
            ; SJMP T0_Output_Digit ; Fall through

T0_Output_Digit:
            MOV   P1, A           ; Output combined value to Port 1

            ; Update display position for next interrupt
            MOV   A, DISPLAY_POS
            INC   A
            ANL   A, #03h        ; Modulo 4 wrap-around
            MOV   DISPLAY_POS, A

            ; --- Restore registers ---
T0_ISR_End:
            MOV   A, TEMP_A     ; Restore registers from RAM
            MOV   PSW, TEMP_PSW
            MOV   B, TEMP_B

            POP   B
            POP   PSW
            POP   ACC
            RETI

;-----------------------------------------------------------------------------
; Helper Subroutines
;-----------------------------------------------------------------------------

; Updates DISPLAY_CHAR3/4 with hex nibbles of the next byte from RAM.
; Sets DISPLAY_CHAR1/2 to Blank. Called every 1 second when STATE is 3.
Display_Next_Hex_Byte:
            PUSH  ACC
            PUSH  B
            PUSH  DPL
            PUSH  DPH

            MOV   R0, DISPLAY_PTR ; Get current RAM address to display
            MOV   A, R0
            CJNE  A, #(RAM_END + 1), DNHB_Continue ; Check if past last address
            ; --- Finished Displaying All Data ---
            MOV   STATE, #04h     ; Transition to END state
            SJMP  DNHB_End

DNHB_Continue:
            MOV   A, @R0          ; Get data byte from RAM
            INC   DISPLAY_PTR     ; Increment pointer for next time

            ; Display hex byte on digits 3 & 4, blank digits 1 & 2
            MOV   DISPLAY_CHAR1, #CHAR_BLANK
            MOV   DISPLAY_CHAR2, #CHAR_BLANK

            MOV   B, A          ; Save original byte in B
            SWAP  A             ; Get high nibble
            ANL   A, #0Fh       ; Isolate high nibble (0-F)
            MOV   DISPLAY_CHAR3, A ; Store hex code in Digit 3 variable

            MOV   A, B          ; Restore original byte
            ANL   A, #0Fh       ; Isolate low nibble (0-F)
            MOV   DISPLAY_CHAR4, A ; Store hex code in Digit 4 variable

DNHB_End:
            POP   DPH
            POP   DPL
            POP   B
            POP   ACC
            RET

;-----------------------------------------------------------------------------
            END
;-----------------------------------------------------------------------------