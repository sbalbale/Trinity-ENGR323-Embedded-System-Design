; Receiver (slave) Configuration Code for multiprocessor UART communications
; Based on C code by Nikolay A. Atanasov

;------------------------------------------------------------------------------------
; Interrupt Vector Table
;------------------------------------------------------------------------------------
ORG     0000h           
    LJMP    MAIN           

ORG     0003h          ; External Interrupt 0 vector
    LJMP    EX0_ISR           

ORG     000Bh          ; Timer 0 vector
    LJMP    Timer0_ISR

ORG     0023h          ; Serial Interrupt vector
    LJMP    ES_ISR

;------------------------------------------------------------------------------------
; Constants
;------------------------------------------------------------------------------------
ADDRESS     EQU     05h     ; Slave Address
DATA_SIZE   EQU     256     ; Size of transmitted data

; 7-Segment Display Codes
R_CODE      EQU     08h
E_CODE      EQU     30h
C_CODE      EQU     72h
D_CODE      EQU     42h
N_CODE      EQU     6Ah

; Number codes (active-low)
ZERO        EQU     01h
ONE         EQU     4Fh
TWO         EQU     12h
THREE       EQU     06h
FOUR        EQU     4Ch
FIVE        EQU     24h
SIX         EQU     60h
SEVEN       EQU     0Fh
EIGHT       EQU     00h
NINE        EQU     0Ch
OFF         EQU     0FFh

;------------------------------------------------------------------------------------
; Bit definitions
;------------------------------------------------------------------------------------
LED         BIT     P1.6   ; Green LED
MSEL1       BIT     P1.5   ; Multiplexer Select bits
MSEL0       BIT     P1.4
RECD_flag   BIT     20h.0  ; Received flag
END_flag    BIT     20h.1  ; End flag

;------------------------------------------------------------------------------------
; Variable declarations
;------------------------------------------------------------------------------------
ORG     0030h

; RAM variables (direct addressing)
count:          DS  2   ; Counts bytes received (short)
interrupt_count: DS  2   ; Counts Timer 0 overflows (short)
refresher:      DS  2   ; Current digit to refresh (short)
digit_one:      DS  1   ; Binary code for digit one
digit_two:      DS  1   ; Binary code for digit two
digit_three:    DS  1   ; Binary code for digit three

; XDATA segment for large array
ORG     0100h
MAIN:   
    ; Disable watchdog timer
    MOV     WDTCN, #0DEh
    MOV     WDTCN, #0ADh

    ; Set SFR page to CONFIG_PAGE
    MOV     SFRPAGE, #00h    ; Assuming CONFIG_PAGE = 0

    ; Initialize device components
    LCALL   Init_Device
    
    ; Enable global interrupts
    SETB    EA
    
    ; Set SFR page to LEGACY_PAGE
    MOV     SFRPAGE, #00h    ; Assuming LEGACY_PAGE = 0

main_loop:
    SJMP    main_loop        ; Infinite loop

;------------------------------------------------------------------------------------
; BCD_7SEG: Convert decimal digit to 7-segment code
;------------------------------------------------------------------------------------
BCD_7SEG:
    MOV     A, R7            ; R7 contains the input digit
    
    CJNE    A, #00h, try_one
    MOV     R7, #ZERO
    RET
try_one:
    CJNE    A, #01h, try_two
    MOV     R7, #ONE
    RET
try_two:
    CJNE    A, #02h, try_three
    MOV     R7, #TWO
    RET
try_three:
    CJNE    A, #03h, try_four
    MOV     R7, #THREE
    RET
try_four:
    CJNE    A, #04h, try_five
    MOV     R7, #FOUR
    RET
try_five:
    CJNE    A, #05h, try_six
    MOV     R7, #FIVE
    RET
try_six:
    CJNE    A, #06h, try_seven
    MOV     R7, #SIX
    RET
try_seven:
    CJNE    A, #07h, try_eight
    MOV     R7, #SEVEN
    RET
try_eight:
    CJNE    A, #08h, try_nine
    MOV     R7, #EIGHT
    RET
try_nine:
    CJNE    A, #09h, default_digit
    MOV     R7, #NINE
    RET
default_digit:
    MOV     R7, #OFF
    RET

;------------------------------------------------------------------------------------
; Receive_Toggle: Toggle SM2 bit to control receiving
;------------------------------------------------------------------------------------
Receive_Toggle:
    ; Save current SFR page
    MOV     R7, SFRPAGE
    
    ; Switch to UART0_PAGE
    MOV     SFRPAGE, #01h    ; Assuming UART0_PAGE = 1
    
    ; Toggle SM2 bit in SCON0
    MOV     A, SCON0
    XRL     A, #04h          ; Toggle SM20 (bit 2)
    MOV     SCON0, A
    
    ; Restore SFR page
    MOV     SFRPAGE, R7
    RET

;------------------------------------------------------------------------------------
; Toggle_T0: Toggle Timer 0 on/off
;------------------------------------------------------------------------------------
Toggle_T0:
    ; Save current SFR page
    MOV     R7, SFRPAGE
    
    ; Switch to TIMER01_PAGE
    MOV     SFRPAGE, #02h    ; Assuming TIMER01_PAGE = 2
    
    ; Toggle Timer 0 run control
    CPL     TR0
    
    ; Toggle Timer 0 overflow interrupt
    MOV     A, IE
    XRL     A, #02h          ; Toggle ET0 (bit 1)
    MOV     IE, A
    
    ; Restore SFR page
    MOV     SFRPAGE, R7
    RET

;------------------------------------------------------------------------------------
; clear_display: Reset seven-segment display
;------------------------------------------------------------------------------------
clear_display:
    ; Save current SFR page
    MOV     R7, SFRPAGE
    
    ; Switch to TIMER01_PAGE
    MOV     SFRPAGE, #02h    ; Assuming TIMER01_PAGE = 2
    
    ; Turn off Timer 0 run control
    CLR     TR0
    
    ; Turn off Timer 0 interrupt
    MOV     A, IE
    ANL     A, #0FDh         ; Clear ET0 (bit 1)
    MOV     IE, A
    
    ; Restore SFR page
    MOV     SFRPAGE, R7
    
    ; Reset flags
    CLR     RECD_flag
    CLR     END_flag
    
    ; Clear display
    MOV     P2, #OFF
    RET

;------------------------------------------------------------------------------------
; Display: Refresh the appropriate display digit
;------------------------------------------------------------------------------------
Display:
    MOV     A, refresher
    
    ; Case 0: MSB
    CJNE    A, #00h, try_case1
    CLR     MSEL1
    CLR     MSEL0
    
    JNB     RECD_flag, disp_off0  ; If not RECD_flag, display OFF
    MOV     P2, #R_CODE
    SJMP    inc_refresher
disp_off0:
    MOV     P2, #OFF
    SJMP    inc_refresher
    
try_case1:
    ; Case 1
    CJNE    A, #01h, try_case2
    CLR     MSEL1
    SETB    MSEL0
    
    JB      RECD_flag, disp_e     ; If RECD_flag or END_flag, display E
    JB      END_flag, disp_e
    MOV     P2, digit_three
    SJMP    inc_refresher
disp_e:
    MOV     P2, #E_CODE
    SJMP    inc_refresher
    
try_case2:
    ; Case 2
    CJNE    A, #02h, try_case3
    SETB    MSEL1
    CLR     MSEL0
    
    JB      RECD_flag, disp_c     ; If RECD_flag, display C
    JNB     END_flag, disp_norm2  ; If END_flag, display N
    MOV     P2, #N_CODE
    SJMP    inc_refresher
disp_c:
    MOV     P2, #C_CODE
    SJMP    inc_refresher
disp_norm2:
    MOV     P2, digit_two
    SJMP    inc_refresher
    
try_case3:
    ; Case 3
    SETB    MSEL1
    SETB    MSEL0
    
    JB      RECD_flag, disp_d     ; If RECD_flag or END_flag, display D
    JB      END_flag, disp_d
    MOV     P2, digit_one
    SJMP    reset_refresher
disp_d:
    MOV     P2, #D_CODE

reset_refresher:
    MOV     refresher, #00h
    RET

inc_refresher:
    INC     refresher
    RET

;------------------------------------------------------------------------------------
; EX0_ISR: External Interrupt 0 Service Routine
;------------------------------------------------------------------------------------
EX0_ISR:
    CLR     RECD_flag        ; Start displaying data
    CLR     END_flag
    RETI

;------------------------------------------------------------------------------------
; Timer0_ISR: Timer 0 Overflow Interrupt Service Routine
;------------------------------------------------------------------------------------
Timer0_ISR:
    ; Save current SFR page
    MOV     R7, SFRPAGE
    
    ; Disable interrupts during critical section
    CLR     EA
    
    ; Switch to TIMER01_PAGE
    MOV     SFRPAGE, #02h    ; Assuming TIMER01_PAGE = 2
    
    ; Reload Timer 0
    MOV     TH0, #0DCh
    MOV     TL0, #00h
    
    ; Re-enable interrupts
    SETB    EA
    
    ; Restore SFR page
    MOV     SFRPAGE, R7
    
    ; Increment interrupt count
    INC     interrupt_count
    MOV     A, interrupt_count
    JNZ     check_high_byte
    INC     interrupt_count+1
check_high_byte:
    
    ; Check if 1 second has passed (interrupt_count != 200)
    MOV     A, interrupt_count
    CJNE    A, #0C8h, not_one_sec
    MOV     A, interrupt_count+1
    CJNE    A, #00h, not_one_sec
    
    ; 1 second has passed
    JB      RECD_flag, reset_counter
    JB      END_flag, reset_counter
    
    ; Check if all data displayed
    MOV     A, count
    CJNE    A, #DATA_SIZE, not_end
    MOV     A, count+1
    CJNE    A, #00h, not_end
    
    ; All data displayed, show END
    SETB    END_flag
    MOV     count, #00h
    MOV     count+1, #00h
    MOV     interrupt_count, #00h
    MOV     interrupt_count+1, #00h
    LCALL   Display
    RETI
    
not_end:
    ; Get next character
    MOV     DPTR, #ram_block
    MOV     A, count         ; Low byte of offset
    MOV     R0, A
    MOV     A, count+1       ; High byte of offset
    MOV     R1, A
    
    ; Calculate address: ram_block + count
    MOV     A, R0
    ADD     A, DPL
    MOV     DPL, A
    MOV     A, R1
    ADDC    A, DPH
    MOV     DPH, A
    
    MOVX    A, @DPTR         ; Get character from xdata
    MOV     R7, A
    
    ; Calculate digit_one (units)
    MOV     B, #10
    DIV     AB               ; A = letter / 10, B = letter % 10
    MOV     R6, A            ; Save tens value
    MOV     A, B             ; Get remainder (units)
    MOV     R7, A
    LCALL   BCD_7SEG         ; Convert to 7-segment code
    MOV     digit_one, R7
    
    ; Calculate digit_two (tens)
    MOV     A, R6            ; Get tens value
    MOV     B, #10
    DIV     AB               ; A = (letter/10) / 10, B = (letter/10) % 10
    MOV     R6, A            ; Save hundreds value
    MOV     A, B             ; Get remainder (tens)
    MOV     R7, A
    LCALL   BCD_7SEG         ; Convert to 7-segment code
    MOV     digit_two, R7
    
    ; Calculate digit_three (hundreds)
    MOV     A, R6            ; Get hundreds value
    MOV     R7, A
    LCALL   BCD_7SEG         ; Convert to 7-segment code
    MOV     digit_three, R7
    
    ; Increment count
    INC     count
    MOV     A, count
    JNZ     reset_counter
    INC     count+1

reset_counter:
    ; Reset interrupt counter
    MOV     interrupt_count, #00h
    MOV     interrupt_count+1, #00h
    LCALL   Display
    RETI

not_one_sec:
    ; Less than 1 second passed, just update display
    LCALL   Display
    RETI

;------------------------------------------------------------------------------------
; ES_ISR: Serial Interrupt Service Routine
;------------------------------------------------------------------------------------
ES_ISR:
    ; Save current SFR page
    MOV     R7, SFRPAGE
    
    ; Switch to UART0_PAGE
    MOV     SFRPAGE, #01h    ; Assuming UART0_PAGE = 1
    
    ; Clear RI flag
    CLR     RI0
    
    ; Turn on LED
    SETB    LED
    
    ; Check if this is an address byte
    MOV     A, SCON0         ; Get SCON0 value
    ANL     A, #04h          ; Isolate SM20 bit
    JZ      receiving_data   ; If SM20=0, we're receiving data
    
    ; Check if address matches
    MOV     A, SBUF0
    CJNE    A, #ADDRESS, exit_isr
    
    ; Address matches - enable receiving
    LCALL   Receive_Toggle   ; Turn on receiving mode
    LCALL   clear_display    ; Clear display
    MOV     count, #00h      ; Reset RAM block pointer
    MOV     count+1, #00h
    SJMP    exit_isr
    
receiving_data:
    ; Store received data in RAM
    MOV     A, SBUF0         ; Get received byte
    
    ; Calculate destination address
    MOV     DPTR, #ram_block
    MOV     R0, count        ; Low byte of offset
    MOV     R1, count+1      ; High byte of offset
    
    MOV     A, R0
    ADD     A, DPL
    MOV     DPL, A
    MOV     A, R1
    ADDC    A, DPH
    MOV     DPH, A
    
    MOV     A, SBUF0         ; Get received byte again
    MOVX    @DPTR, A         ; Store in xdata
    
    ; Increment count
    INC     count
    MOV     A, count
    JNZ     check_data_complete
    INC     count+1
    
check_data_complete:
    ; Check if all data received
    MOV     A, count
    CJNE    A, #LOW(DATA_SIZE), exit_isr
    MOV     A, count+1
    CJNE    A, #HIGH(DATA_SIZE), exit_isr
    
    ; All data received
    LCALL   Receive_Toggle   ; Turn off receiving mode
    MOV     count, #00h      ; Reset count
    MOV     count+1, #00h
    SETB    RECD_flag        ; Set received flag
    LCALL   Toggle_T0        ; Start timer for display

exit_isr:
    ; Restore SFR page
    MOV     SFRPAGE, R7
    RETI

;------------------------------------------------------------------------------------
; Initialization Subroutines
;------------------------------------------------------------------------------------

;------------------------------------------------------------------------------------
; Init_Device: Initialize all peripherals
;------------------------------------------------------------------------------------
Init_Device:
    LCALL   Timer_Init
    LCALL   UART_Init
    LCALL   Port_IO_Init
    LCALL   Oscillator_Init
    LCALL   Interrupts_Init
    LCALL   Address_Init
    LCALL   LED_Init
    RET

;------------------------------------------------------------------------------------
; Timer_Init: Configure timers
;------------------------------------------------------------------------------------
Timer_Init:
    ; Switch to TIMER01_PAGE
    MOV     SFRPAGE, #02h    ; Assuming TIMER01_PAGE = 2
    
    ; Set timer modes
    MOV     TMOD, #21h       ; Timer 1: 8-bit auto-reload, Timer 0: 16-bit
    
    ; Configure Timer 0
    MOV     TH0, #0DCh
    MOV     TL0, #00h
    
    ; Configure Timer 1 for 9600 baud
    MOV     TH1, #0FAh
    
    ; Enable Timer 1 and configure INT0 as edge triggered
    MOV     TCON, #41h
    RET

;------------------------------------------------------------------------------------
; UART_Init: Configure UART
;------------------------------------------------------------------------------------
UART_Init:
    ; Switch to UART0_PAGE
    MOV     SFRPAGE, #01h    ; Assuming UART0_PAGE = 1
    
    ; Configure SCON0 for multiprocessor mode
    MOV     SCON0, #0F0h
    RET

;------------------------------------------------------------------------------------
; Port_IO_Init: Configure I/O ports
;------------------------------------------------------------------------------------
Port_IO_Init:
    ; Switch to CONFIG_PAGE
    MOV     SFRPAGE, #00h    ; Assuming CONFIG_PAGE = 0
    
    ; Enable UART0 I/O
    MOV     XBR0, #04h
    
    ; Enable /INT0 input
    MOV     XBR1, #04h
    
    ; Enable weak pull-ups
    MOV     XBR2, #40h
    RET

;------------------------------------------------------------------------------------
; Oscillator_Init: Configure oscillator
;------------------------------------------------------------------------------------
Oscillator_Init:
    ; Switch to CONFIG_PAGE
    MOV     SFRPAGE, #00h    ; Assuming CONFIG_PAGE = 0
    
    ; Enable external oscillator
    MOV     OSCXCN, #67h
    
    ; Wait loop for oscillator to stabilize
    MOV     R6, #0Ch         ; High byte of delay count
    MOV     R7, #00h         ; Low byte of delay count
osc_delay:
    DJNZ    R7, osc_delay
    DJNZ    R6, osc_delay
    
    ; Check XTLVLD flag
check_xtl:
    MOV     A, OSCXCN
    ANL     A, #80h
    JZ      check_xtl
    
    ; Switch to external oscillator
    MOV     CLKSEL, #01h
    
    ; Disable internal oscillator
    MOV     OSCICN, #00h
    RET

;------------------------------------------------------------------------------------
; Interrupts_Init: Configure interrupts
;------------------------------------------------------------------------------------
Interrupts_Init:
    ; Enable UART0 and EX0 interrupts
    MOV     IE, #11h
    
    ; Set UART0 interrupt priority
    MOV     IP, #10h
    RET

;------------------------------------------------------------------------------------
; Address_Init: Configure slave address
;------------------------------------------------------------------------------------
Address_Init:
    ; Switch to UART0_PAGE
    MOV     SFRPAGE, #01h    ; Assuming UART0_PAGE = 1
    
    ; Set slave address
    MOV     SADDR0, #ADDRESS
    
    ; Set address mask
    MOV     SADEN0, #0FFh
    RET

;------------------------------------------------------------------------------------
; LED_Init: Initialize LED
;------------------------------------------------------------------------------------
LED_Init:
    ; Configure P1.6 as push-pull output
    MOV     A, P1MDOUT
    ORL     A, #40h
    MOV     P1MDOUT, A
    
    ; Turn off LED
    CLR     LED
    RET

;------------------------------------------------------------------------------------
; XDATA segment for RAM block
;------------------------------------------------------------------------------------
ORG     0000h
ram_block:   DS  DATA_SIZE   ; Reserve 256 bytes in XDATA space

END