		ORG 0000H
	    AJMP MAIN
	
		ORG 000BH
		AJMP TDM_ISR
	
		ORG 0023H
		AJMP SERIAL_ISR
	
		ORG 0100H         ; Start of program (skip interrupt vectors if not used)

MAIN:
	    ; ============ UART Initialization ============
	    MOV TMOD, #21H       ; Timer1 Mode 2 (8-bit auto-reload), Timer0 mode 1
	    MOV TH1, #0FDH       ; Baud rate 9600 for 11.0592 MHz crystal
	                         ; Formula: TH1 = 256 - (Crystal / (384 * Baud rate))
	                         ; TH1 = 256 - (11.0592 MHz / (384 * 9600)) = 253 = 0xFD
	    MOV TL1, #0FDH       ; Load same value into TL1
	    SETB TR1             ; Start Timer1
	
		; Initialise timer 0
		; 1 instruction cycle = 1.0851 us
		; 5ms = approx 4608*1.0851 us
		MOV TH0, #0EDh		; FFFFh - 1200h (4608d) = EDFFh
		MOV TL0, #0FFh		; ~5 ms timer for 11.0592 MHz crystal 
		SETB ET0
		SETB TR0
	
	    MOV SCON, #0D0H       ; UART Mode 3, REN=1 (enable receiver)
	    SETB EA              ; Enable global interrupts
	    SETB ES              ; Enable serial interrupt
	
		;-------------------------------------------------------------------------
		ONES EQU 70h
		TENS EQU 71h
		HUNDREDS EQU 72h
		THOUSANDS EQU 73h
	
		MOV ONES, #09h
		MOV TENS, #19h
		MOV HUNDREDS, #29h
		MOV THOUSANDS, #39h
	
		MOV R0, #70h		; For TDM		
		MOV R1, #30h		; For saving data
		MOV R6, #00h	   	; R6 for 1-second delays
	
		SJMP WAIT

    ; Optional: Indicate ready state (e.g., turn on LED)
WAIT:
		NOP
		CJNE R1, #70h, WAIT
		MOV R1, #30h	; Take R1 back for displaying
		MOV R6, #00h	; Start counting one second
		ACALL DISPLAY
	
	    SJMP WAIT      ; Wait forever (everything happens in ISR)

; ============ DISPLAY FUNCTION ===============
DISPLAY:
		ACALL ONESEC_DELAY
	
		; First make all numbers 0
		MOV ONES, #00h
		MOV TENS, #10h
		MOV HUNDREDS, #20h
		MOV THOUSANDS, #30h
	
	
		ACALL ONESEC_DELAY
	
		; Now start displaying the values stored in the RAM 0x30 through 0x6F
		; Do so with a loop

LOOP:
		; Check if displaying is done. Else, MOVE.
		CJNE R1, #70h, MOVE
	
		MOV R1, #30h	; Reset R1 again to avoid displaying again
	
		; Display 4321 as finished
		MOV ONES, #01h
		MOV TENS, #12h
		MOV HUNDREDS, #23h
		MOV THOUSANDS, #34h
	
		RET

; Decode the number and store it in ONES, TENS, HUNDREDS, and THOUSANDS
MOVE:
		MOV A, @R1
		MOV B, #10
		DIV AB
	
		; Quotient stores the number of tens (in decimal). Add #10h to shift digit correctly.
		ADD A, #10h
		MOV TENS, A
		; Remainder stores the number of ones (in decimal)
		MOV ONES, B
		; Will display between 00 and 63 decimal (00 - 3F hex)
	
		; Loop back until everything is displayed
		ACALL ONESEC_DELAY
		INC R1
		SJMP LOOP


ONESEC_DELAY:
		NOP
		; Check if one second has passed. If not, loop back
		CJNE R6, #200, ONESEC_DELAY
		; Reset counter for next second. Return.
		MOV R6, #00h
		RET


; ============ Interrupt Interrupt Handler ============

; TDM display for 4-digit 7-segment display
TDM_ISR:
		; Disable global interrupts
		CLR EA	
		
		; Clear timer flag and reload timer
		CLR TF0
		MOV TH0, #0ECh
		MOV TL0, #07Ch

		; Put impedance high in P3.0
		SETB P3.0

	 	; Re-enable global interrupts
		SETB EA

		; For 1-second delay
		INC R6

		; Move into port 1 the value pointed by R0 and increase R0
		MOV P1, @R0
		INC R0

		; Check if R0 is out of bounds
		CJNE R0, #74h, DONE

		; If out of bounds, reset it
		MOV R0, #70h
		SJMP DONE

; Leave the ISR
DONE:
		NOP
		RETI

; ============== Serial ISR =====================================
SERIAL_ISR:
	    JNB RI, NO_RX        ; If RI == 0, no data received
	    CLR RI               ; Clear receive interrupt flag
	
	    JNB RB8, IS_DATA     ; If RB8 == 0, it's a data byte
	    ; Else, it's an address byte
	    MOV A, SBUF
	    CJNE A, #05h, NO_RX  ; If address doesn't match, ignore
	    CLR SM2              ; Enable reception of data bytes
	    SJMP NO_RX

IS_DATA:
	    MOV A, SBUF				; Move the received byte into the accumulator
		CJNE A, #40h, NOT_LAST	; Check if we've finished receiving data (max 0x3F)
		MOV THOUSANDS, #34h		; Display a "finished" code (4321 in 7-seg)
		MOV HUNDREDS, #23h
		MOV TENS, #12h
		MOV ONES, #01h
		INC R1					; Increase R1 to start displaying
		SJMP NO_RX				; Leave ISR

NOT_LAST:	
	    MOV @R1, A				; Move received byte in respective address in RAM
		INC R1					; Go to next address in RAM

NO_RX:
   	 RETI

END