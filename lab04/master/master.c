#include <c8051f120.h>
//------------------------------------------------------------------------------------
// Global CONSTANTS
//------------------------------------------------------------------------------------
#define ADDRESS 0x05
#define S 0x24 // Letter codes for seven-segment display
#define E 0x30
#define N 0x6A
#define T 0x70
#define D 0x42
#define O 0x62

sbit LED = P1^6;

//------------------------------------------------------------------------------------
// Function PROTOTYPES
//------------------------------------------------------------------------------------
void UART_Init();
void Interrupts_Init();
void Timer_Init();
void Port_IO_Init();
void Oscillator_Init();
void LED_Init(void);
void fillup();

//------------------------------------------------------------------------------------
// Variable Declaration
//------------------------------------------------------------------------------------
int xdata fill[64];
int data dummy = 0;
int n = 0;
short refresher = 0;
sbit MSEL1 = P1^5; // Multiplexer Select bits
sbit MSEL0 = P1^4;

//------------------------------------------------------------------------------------
// MAIN Routine
//------------------------------------------------------------------------------------
void main (void) {
    // disable watchdog timer
    WDTCN = 0xde;
    WDTCN = 0xad;
    
    Timer_Init();
    UART_Init();
    Interrupts_Init();
    Port_IO_Init();
    Oscillator_Init();
    LED_Init();
    
    SFRPAGE = LEGACY_PAGE; // Page to sit in for now
    
    while (1) { 
        // spin forever
    }
}

//-----------------------------------------------------------------------------
// Initialization Subroutines
//-----------------------------------------------------------------------------
void LED_Init(void)
{
    P1MDOUT |= 0x40;
    LED = 0;
}

void Timer_Init()
{
    SFRPAGE = TIMER01_PAGE;
    TMOD = 0x21;     // Timer 0 in 16-bit mode, Timer 1 in 8-bit auto-reload mode
    TH0 = 0xDC;      // Load initial value into Timer 0
    TL0 = 0x00;
    TH1 = 0xFA;      // Load initial value for 9600 baud rate into TH1
    TCON = 0x41;     // TR1 = 1; enable Timer 1 Run Control
                      // IT0 = 1; /INT0 is edge triggered, falling-edge
}

void UART_Init()
{
    SFRPAGE = UART0_PAGE;
    SCON0 = 0xC0;    // Mode 3 (9-bit UART), TB8 = 0, REN = 0
}

void Interrupts_Init()
{
    IE = 0x91;       // Enable External Interrupt 0, Timer 0, and Serial Interrupts
    IP = 0x10;       // PS0 = 1: UART0 Interrupt Priority Control
}

void Oscillator_Init()
{
    // Configure The External Oscillator to use a 22.1184 MHz frequency
    int i = 0;
    SFRPAGE = CONFIG_PAGE;
    
    // Step 1. Enable the external oscillator.
    OSCXCN = 0x67;
    
    // Step 2. Wait 1ms for initialization
    for (i = 0; i < 3000; i++);
    
    // Step 3. Poll for XTLVLD => '1'
    while ((OSCXCN & 0x80) == 0);
    
    // Step 4. Switch the system clock to the external oscillator.
    CLKSEL = 0x01;
    OSCICN = 0x00;
}

void Port_IO_Init()
{
    // P0.0 - TX0 (UART0), Push-Pull, Digital
    SFRPAGE = CONFIG_PAGE;
    P0MDOUT = 0x01;  // Set P0.0 to Push-Pull output mode for UART TX
    
    // Configure P1 and P2 for display control and data
    P1MDOUT |= 0x30;  // Set P1.4 and P1.5 as outputs for multiplexer control
    P2MDOUT = 0xFF;   // Set P2 as output for display data
    
    XBR0 = 0x04;      // Route UART0 TX to P0.0
    XBR1 = 0x04;      // Route external interrupt 0 to P0.2
    XBR2 = 0x40;      // Enable crossbar
}

//-----------------------------------------------------------------------------
// Support Subroutines
//-----------------------------------------------------------------------------
// Function to write 0x00 to 0xFF to RAM
void fillup()
{
    char SFRPAGE_SAVE = SFRPAGE; // Save Current SFR page
    int i;
    
    for(i=0; i<64; i++)
    {
        fill[i] = i;  // Write values from 0x00 to 0xFF to array
        
    }

    
    dummy = 1;  // Set flag to indicate RAM has been filled
    
    SFRPAGE = TIMER01_PAGE;
    TR0 |= 1;   // Turn on Timer 0 run control
    ET0 |= 1;   // Turn on Timer 0 overflow interrupt
    
    SFRPAGE = SFRPAGE_SAVE; // Restore SFR page
}

//-----------------------------------------------------------------------------------
// Interrupt Service Routines
//-----------------------------------------------------------------------------------
void EX0_ISR (void) interrupt 0
{
    if (dummy == 0)
    {
        fillup();  // Fill RAM with data when button is pressed first time
    }
    else
    {
        TB80 = 1;        // Set TB8 bit to indicate address byte
        SBUF0 = ADDRESS;  // Send address byte to specify receiver
    }
}

void Timer0_ISR (void) interrupt 1
{
    char SFRPAGE_SAVE = SFRPAGE; // Save Current SFR page
    
    // Reload Timer 0 to start counting over
    EA = 0;  // Disable interrupts (critical section)
    SFRPAGE = TIMER01_PAGE;
    TH0 = 0xDC;  // Reload Timer 0 high byte
    TL0 = 0x00;  // Reload Timer 0 low byte
    EA = 1;      // Re-enable interrupts
    
    SFRPAGE = SFRPAGE_SAVE; // Restore SFR page
    
    // Time-division multiplexing for 7-segment display
    if(dummy != 0)
    {
        switch(refresher)
        {
            case 0:
                MSEL1 = 0;
                MSEL0 = 0;
                if(dummy == 1)
                    P2 = D;  // Display "D" for "DONE"
                else
                    P2 = S;  // Display "S" for "SENT"
                refresher++;
                break;
                
            case 1:
                MSEL1 = 0;
                MSEL0 = 1;
                if(dummy == 1)
                    P2 = O;  // Display "O" for "DONE"
                else
                    P2 = E;  // Display "E" for "SENT"
                refresher++;
                break;
                
            case 2:
                MSEL1 = 1;
                MSEL0 = 0;
                P2 = N;      // Display "N" for both "DONE" and "SENT"
                refresher++;
                break;
                
            case 3:
                MSEL1 = 1;
                MSEL0 = 1;
                if(dummy == 1)
                    P2 = E;  // Display "E" for "DONE"
                else
                    P2 = T;  // Display "T" for "SENT"
                refresher = 0;
                break;
                
            default: 
                break;
        }
    }
}

//-----------------------------------------------------------------------------------
// UART Transmit Interrupt Service Routine
//-----------------------------------------------------------------------------------
void ES_ISR (void) interrupt 4
{
    TI0 = 0;    // Clear transmit interrupt flag
    
    TB80 = 0;   // Clear TB8 bit (this is data, not an address)
    
    // SBUF0 = 0x0F;  // Send dummy byte to clear the interrupt flag

    if(n < 64)
    {
        // SBUF0 = fill[n];  // Send data byte
        SBUF0 = 24; // Send the value 24
        n++;
    }
    else
    {
        dummy = 2;  // All data sent, update display to "SENT"
        LED = 1;    // Turn on LED to indicate completion
    }

}
