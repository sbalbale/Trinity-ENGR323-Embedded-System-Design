;-----------------------------------------------------------------------------
; UART Slave Receiver
; This program configures the 8051 as a UART slave receiver that can:
; 1. Determine if it is the targeted-receiver
; 2. Receive data and store in RAM locations 30h-6Fh
; 3. Display "DONE" when all bytes are received
; 4. Display received data sequentially with 1-second intervals 
; 5. Display "END" when completed
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Constants
;-----------------------------------------------------------------------------
SLAVE_ADDR      EQU     05h     ; Slave address (must match master)
DATA_SIZE       EQU     40h     ; 64 bytes of data (0x00-0x3F)

; 7-segment display codes (active low)
ZERO            EQU     01h     ; 0
ONE             EQU     4Fh     ; 1
TWO             EQU     12h     ; 2
THREE           EQU     06h     ; 3
FOUR            EQU     4Ch     ; 4
FIVE            EQU     24h     ; 5
SIX             EQU     20h     ; 6
SEVEN           EQU     0Fh     ; 7
EIGHT           EQU     00h     ; 8
NINE            EQU     04h     ; 9
LETTER_D        EQU     42h     ; d
LETTER_O        EQU     11h     ; o
LETTER_N        EQU     6Ah     ; n
LETTER_E        EQU     30h     ; E

; Display messages
; RAM locations for display buffer
DISP_BUF        EQU     70h     ; Start of display buffer (4 bytes)

;-----------------------------------------------------------------------------
; Interrupt Vector Table
;-----------------------------------------------------------------------------
            ORG     0000h
            SJMP    MAIN            ; Reset vector

            ORG     0023h           ; Serial interrupt vector
            LJMP    SERIAL_ISR

            ORG     000Bh           ; Timer 0 interrupt vector
            LJMP    TIMER0_ISR

            ORG     0013h           ; External interrupt 1 vector
            LJMP    EXT1_ISR

;-----------------------------------------------------------------------------
; Main Program
;-----------------------------------------------------------------------------
            ORG     0030h
MAIN:       MOV     SP, #60h        ; Initialize stack pointer

            ; Initialize variables
            MOV     R7, #00h        ; Display position counter
            MOV     20h, #00h       ; Mode (0=Waiting, 1=Receiving, 2=Done, 3=Display, 4=End)
            MOV     21h, #00h       ; Data index for display
            MOV     22h, #00h       ; Timer counter for 1-second intervals
            
            ; Setup serial port (Mode 3 - 9-bit UART)
            MOV     SCON, #0F0h     ; Mode 3, SM2=1 (enable multiprocessor), REN=1
            
            ; Set baud rate using Timer 1 (assuming 11.0592 MHz crystal)
            MOV     TMOD, #21h      ; Timer 0: 16-bit mode, Timer 1: 8-bit auto-reload
            MOV     TH1, #0FDh      ; 9600 baud rate with 11.0592 MHz crystal
            SETB    TR1             ; Start Timer 1
            
            ; Setup Timer 0 for display refresh (5ms intervals)
            MOV     TH0, #0ECh      ; Load high byte for 5ms delay
            MOV     TL0, #78h       ; Load low byte for 5ms delay
            
            ; Setup display buffer with "----" initially
            MOV     DISP_BUF+0, #40h    ; "-"
            MOV     DISP_BUF+1, #40h    ; "-"
            MOV     DISP_BUF+2, #40h    ; "-"
            MOV     DISP_BUF+3, #40h    ; "-"
            
            ; Enable interrupts
            SETB    ES              ; Enable serial interrupt
            SETB    ET0             ; Enable Timer 0 interrupt
            SETB    EX1             ; Enable External interrupt 1
            SETB    EA              ; Enable global interrupts
            
            ; Configure P1 for output (7-segment display)
            MOV     P1, #0FFh       ; Turn off all segments initially

MAIN_LOOP:  SJMP    MAIN_LOOP       ; Wait for interrupts

;-----------------------------------------------------------------------------
; Serial Interrupt Service Routine
;-----------------------------------------------------------------------------
SERIAL_ISR: PUSH    ACC
            PUSH    PSW
            
            CLR     RI              ; Clear receive interrupt flag
            
            ; Check if SM2 is set (waiting for address)
            JNB     SM2, RECEIVE_DATA
            
            ; Address mode - check if this slave is being addressed
            MOV     A, SBUF
            CJNE    A, #SLAVE_ADDR, NOT_OUR_ADDR
            
            ; This slave is being addressed
            CLR     SM2             ; Clear SM2 to receive data bytes
            MOV     R0, #30h        ; Initialize data pointer to RAM location 30h
            MOV     20h, #01h       ; Set mode to receiving
            SJMP    SERIAL_EXIT
            
NOT_OUR_ADDR:
            ; Not our address, stay in address mode
            SJMP    SERIAL_EXIT
            
RECEIVE_DATA:
            ; We are receiving a data byte
            MOV     A, SBUF         ; Get received data
            MOV     @R0, A          ; Store in RAM
            INC     R0              ; Increment pointer
            
            ; Check if we've received all data
            MOV     A, R0
            CJNE    A, #70h, SERIAL_EXIT  ; If not at end of buffer, continue
            
            ; All data received
            SETB    SM2             ; Reset SM2 to wait for next address byte
            MOV     20h, #02h       ; Set mode to Done
            
            ; Setup "DONE" message in display buffer
            MOV     DISP_BUF+0, #LETTER_D
            MOV     DISP_BUF+1, #LETTER_O
            MOV     DISP_BUF+2, #LETTER_N
            MOV     DISP_BUF+3, #LETTER_E
            
            ; Start Timer 0 for display
            SETB    TR0

SERIAL_EXIT:
            POP     PSW
            POP     ACC
            RETI

;-----------------------------------------------------------------------------
; Timer 0 Interrupt Service Routine
;-----------------------------------------------------------------------------
TIMER0_ISR: PUSH    ACC
            PUSH    PSW
            
            ; Reload timer for next 5ms interval
            MOV     TH0, #0ECh
            MOV     TL0, #78h
            
            ; Update display refresh counter
            INC     22h
            MOV     A, 22h
            
            ; Check if 1 second has passed (200 * 5ms = 1 second)
            CJNE    A, #200, REFRESH_DISPLAY
            MOV     22h, #0         ; Reset counter
            
            ; Check current mode
            MOV     A, 20h
            CJNE    A, #02h, CHECK_DISPLAY_MODE  ; If not in Done mode, check display mode
            MOV     20h, #03h       ; Switch to Display mode
            MOV     21h, #00h       ; Reset display index
            SJMP    UPDATE_DATA_DISPLAY
            
CHECK_DISPLAY_MODE:
            CJNE    A, #03h, CHECK_END_MODE      ; If not in Display mode, check End mode
            
            ; In Display mode - update display with next data byte
UPDATE_DATA_DISPLAY:
            MOV     A, 21h          ; Get current data index
            ADD     A, #30h         ; Add base address of data
            MOV     R0, A           ; R0 points to current data byte
            MOV     A, @R0          ; Get data byte
            
            ; Convert to BCD and display
            MOV     B, #100
            DIV     AB              ; A = hundreds, B = remainder
            MOV     DISP_BUF+1, A   ; Store hundreds digit
            
            MOV     A, B
            MOV     B, #10
            DIV     AB              ; A = tens, B = ones
            MOV     DISP_BUF+2, A   ; Store tens digit
            MOV     DISP_BUF+3, B   ; Store ones digit
            
            MOV     DISP_BUF+0, #40h ; Show "-" in first position
            
            ; Convert BCD to 7-segment codes
            MOV     R0, #DISP_BUF+1
            LCALL   CONVERT_BCD_TO_7SEG
            MOV     R0, #DISP_BUF+2
            LCALL   CONVERT_BCD_TO_7SEG
            MOV     R0, #DISP_BUF+3
            LCALL   CONVERT_BCD_TO_7SEG
            
            ; Increment display index
            INC     21h
            MOV     A, 21h
            CJNE    A, #DATA_SIZE, REFRESH_DISPLAY ; If not at end of data, continue
            
            ; All data displayed, switch to End mode
            MOV     20h, #04h       ; Set mode to End
            
            ; Setup "END " message
            MOV     DISP_BUF+0, #LETTER_E
            MOV     DISP_BUF+1, #LETTER_N
            MOV     DISP_BUF+2, #LETTER_D
            MOV     DISP_BUF+3, #40h ; "-"
            SJMP    REFRESH_DISPLAY
            
CHECK_END_MODE:
            ; Nothing special to do in End mode
            
REFRESH_DISPLAY:
            ; Update the display based on current position
            MOV     A, R7
            
            ; Select digit position and get segment pattern
            CJNE    A, #00h, CHECK_POS1
            MOV     A, #00h         ; Position code for digit 0
            MOV     B, DISP_BUF+0   ; Get segment pattern
            SJMP    OUTPUT_DISPLAY
            
CHECK_POS1: CJNE    A, #01h, CHECK_POS2
            MOV     A, #10h         ; Position code for digit 1
            MOV     B, DISP_BUF+1   ; Get segment pattern
            SJMP    OUTPUT_DISPLAY
            
CHECK_POS2: CJNE    A, #02h, CHECK_POS3
            MOV     A, #20h         ; Position code for digit 2
            MOV     B, DISP_BUF+2   ; Get segment pattern
            SJMP    OUTPUT_DISPLAY
            
CHECK_POS3: ; Must be position 3
            MOV     A, #30h         ; Position code for digit 3
            MOV     B, DISP_BUF+3   ; Get segment pattern
            
OUTPUT_DISPLAY:
            ORL     A, B            ; Combine position and segment pattern
            MOV     P1, A           ; Output to display
            
            ; Update position for next time
            INC     R7
            MOV     A, R7
            CJNE    A, #04h, TIMER0_EXIT
            MOV     R7, #00h
            
TIMER0_EXIT:
            POP     PSW
            POP     ACC
            RETI

;-----------------------------------------------------------------------------
; External Interrupt 1 Service Routine
;-----------------------------------------------------------------------------
EXT1_ISR:   PUSH    ACC
            PUSH    PSW
            
            ; Use external interrupt to start display of received data
            MOV     A, 20h
            CJNE    A, #02h, EXT1_EXIT  ; If not in Done mode, ignore
            
            MOV     20h, #03h       ; Switch to Display mode
            MOV     21h, #00h       ; Reset display index
            MOV     22h, #0         ; Reset timer counter
            
EXT1_EXIT:  POP     PSW
            POP     ACC
            RETI

;-----------------------------------------------------------------------------
; Convert BCD to 7-segment code
; Input: R0 points to BCD value
; Output: 7-segment code replaces BCD value at [R0]
;-----------------------------------------------------------------------------
CONVERT_BCD_TO_7SEG:
            PUSH    ACC
            PUSH    PSW
            
            MOV     A, @R0          ; Get BCD value
            
            ; Convert to 7-segment code using lookup table
            CJNE    A, #00h, TRY_ONE
            MOV     @R0, #ZERO
            SJMP    CONVERT_EXIT
            
TRY_ONE:    CJNE    A, #01h, TRY_TWO
            MOV     @R0, #ONE
            SJMP    CONVERT_EXIT
            
TRY_TWO:    CJNE    A, #02h, TRY_THREE
            MOV     @R0, #TWO
            SJMP    CONVERT_EXIT
            
TRY_THREE:  CJNE    A, #03h, TRY_FOUR
            MOV     @R0, #THREE
            SJMP    CONVERT_EXIT
            
TRY_FOUR:   CJNE    A, #04h, TRY_FIVE
            MOV     @R0, #FOUR
            SJMP    CONVERT_EXIT
            
TRY_FIVE:   CJNE    A, #05h, TRY_SIX
            MOV     @R0, #FIVE
            SJMP    CONVERT_EXIT
            
TRY_SIX:    CJNE    A, #06h, TRY_SEVEN
            MOV     @R0, #SIX
            SJMP    CONVERT_EXIT
            
TRY_SEVEN:  CJNE    A, #07h, TRY_EIGHT
            MOV     @R0, #SEVEN
            SJMP    CONVERT_EXIT
            
TRY_EIGHT:  CJNE    A, #08h, TRY_NINE
            MOV     @R0, #EIGHT
            SJMP    CONVERT_EXIT
            
TRY_NINE:   CJNE    A, #09h, CONVERT_DEFAULT
            MOV     @R0, #NINE
            SJMP    CONVERT_EXIT
            
CONVERT_DEFAULT:
            ; If not a valid digit, display blank
            MOV     @R0, #0FFh
            
CONVERT_EXIT:
            POP     PSW
            POP     ACC
            RET

            END