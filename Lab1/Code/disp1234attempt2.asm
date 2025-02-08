ORG 0000H
    AJMP MAINPROG

ORG 000BH; Timer 0 overflow interrupt vector
    AJMP ISRTF0; Main program
ORG 0100H
MAINPROG:
  ; Initialize the display
    MOV P1, #00H ; Clear P1 to turn off all segments initially

  ; Selective active register bank (not used in this example)
  ;...

  ; Configure TMOD
    MOV TMOD, #11H; Set mode 1 for timer 0 and timer 1

  ; Initialize timer 0 with a starting number
    MOV TH0, #3CH ; Reload value for 5 ms interrupt
    MOV TL0, #0B0H

  ; Enable interrupts
    SETB EA
    SETB ET0

WAIT:
  ; Mainline program waits here
    SJMP WAIT; Timer 0 interrupt service routine
ISRTF0:
  ; Set up the starting RAM location of SP
    MOV SP, #35H

  ; Protect the critical region and reinitialize Timer 0
    CLR EA
    MOV TH0, #3CH; Reload value for 5 ms interrupt
    MOV TL0, #0B0H
    SETB EA

  ; Refresh the digits (using direct addressing)
    MOV A, 30H      ; Load the first digit counter
    CJNE A, #4, SKIP_RESET_1; Check if all digits displayed
    MOV 30H, #0      ; Reset the first digit counter
    SKIP_RESET_1:
    LCALL DISP_DIGIT ; Display the digit
    INC 30H        ; Increment the first digit counter

    RETI; Subroutine to display a digit on a 7-segment display; Input: A = digit to display
DISP_DIGIT:
    MOV DPTR, #DIGIT_TABLE
    MOVC A, @A+DPTR
    MOV P1, A
    RET; Table of digit codes for a 7-segment display
DIGIT_TABLE:
    DB 0C0H; 0
    DB 0F9H; 1
    DB 0A4H; 2
    DB 0B0H; 3
    DB 099H; 4
    DB 092H; 5
    DB 082H; 6
    DB 0F8H; 7
    DB 080H; 8
    DB 090H; 9

END