// A.3 Transmitter (master) Configuration Code that allows multiprocessor communications via universal asynchronous receiver and transmitter (UART)
#include <c8051f120.h>

//------------------------------------------------------------------------------------
// Global CONSTANTS
//------------------------------------------------------------------------------------
#define ADDRESS 0x05
#define S 0x24 // Letter codes
#define E 0x30
#define N 0x6A
#define T 0x70
#define D 0x42
#define O 0x62

//------------------------------------------------------------------------------------
// Function PROTOTYPES
//------------------------------------------------------------------------------------
void UART_Init();
void Interrupts_Init();
void Timer_Init();
void Port_IO_Init();
void Oscillator_Init();
void LED_Init(void);

//------------------------------------------------------------------------------------
// Variable Declaration
//------------------------------------------------------------------------------------
int xdata fill[9];
int data dummy = 0;
int n = 0;
short refresher = 0;
int led_flash_counter = 0;

sbit MSEL1 = P1 ^ 5; // Multiplexer Select bits
sbit MSEL0 = P1 ^ 4;

sbit LED = P1 ^ 6; // green LED: '1' = ON; '0' = OFF

//------------------------------------------------------------------------------------
// MAIN Routine
//------------------------------------------------------------------------------------
void main(void)
{
    // Disable watchdog timer
    WDTCN = 0xde;
    WDTCN = 0xad;

    Timer_Init();
    UART_Init();
    Interrupts_Init();
    Port_IO_Init();
    Oscillator_Init();
    LED_Init();

    SFRPAGE = LEGACY_PAGE; // Set to legacy page

    while (1)
    { // Spin forever
    }
}

void LED_Init(void)
{
    P1MDOUT |= 0x40;
    LED = 0;
}

//-----------------------------------------------------------------------------
// Initialization Subroutines
//-----------------------------------------------------------------------------
void Timer_Init()
{
    SFRPAGE = TIMER01_PAGE;
    TMOD = 0x21;
    // Timer 0 uses a pre-scaled SYSCLK; Timer 1 for baud rate generation
    TH0 = 0xDC; // Load initial value into Timer 0
    TL0 = 0x00;
    // TH1 = 0xFA;  // Load initial value into Timer 1
    TH1 = 0xF4; // Load initial value into Timer 1 for 9600 baud rate
    TCON = 0x41; // Enable Timer 1 and set INT0 as edge triggered
}

void UART_Init()
{
    SFRPAGE = UART0_PAGE;
    SCON0 = 0xC0;
}

void Interrupts_Init()
{
    IE = 0x91;
    IP = 0x10; // Set UART0 interrupt priority
}

void Oscillator_Init()
{
    int i = 0;
    SFRPAGE = CONFIG_PAGE;
    OSCXCN = 0x67; // Enable external oscillator (22.1184 MHz)
    for (i = 0; i < 3000; i++)
        ; // Wait for oscillator to stabilize
    while ((OSCXCN & 0x80) == 0)
        ;          // Wait for XTLVLD flag
    CLKSEL = 0x01; // Switch to external oscillator
    OSCICN = 0x00;
}

void Port_IO_Init()
{
    // P0.0 - TX0 (UART0) as Push-Pull Digital Output
    SFRPAGE = CONFIG_PAGE;
    P0MDOUT = 0x01; // Set P0.0 to push-pull mode
    XBR0 = 0x04;    // Route UART0 TX to P0.0
    XBR1 = 0x04;    // Route external interrupt 0 to P0.2
    XBR2 = 0x40;    // Enable crossbar and weak pull-ups
}

//-----------------------------------------------------------------------------
// Support Subroutines
//-----------------------------------------------------------------------------
// The following routine writes 00 to FF into a RAM array.
void fillup()
{
    char SFRPAGE_SAVE = SFRPAGE; // Save current SFR page
    // int i;
    // for (i = 0; i < 256; i++)
    // {
    //     fill[i] = i; // Write values from 0x00 to 0xFF into array "fill"
    // }

    // send 0x00 to 0xFF to the slave, manually add the data to the array
    fill[0] = 0x00;
    fill[1] = 0x00;
    fill[2] = 0x00;
    fill[3] = 0x00;
    fill[4] = 0x00;
    fill[5] = 0xFF;
    fill[6] = 0xFF;
    fill[7] = 0xFF;
    fill[8] = 0xFF;
    fill[9] = 0xFF;

    dummy = 1;
    SFRPAGE = TIMER01_PAGE;
    TR0 |= 1;               // Turn on Timer 0 run control
    ET0 |= 1;               // Enable Timer 0 overflow interrupt
    SFRPAGE = SFRPAGE_SAVE; // Restore SFR page
}

//-----------------------------------------------------------------------------------
// Interrupt Service Routine
//-----------------------------------------------------------------------------------
void EX0_ISR(void) interrupt 0
{
    if (dummy == 0)
        fillup();
    else
    {
        TB80 = 1;        // Make all slaves listen
        SBUF0 = ADDRESS; // Send out address to specify listener
    }
}

void Timer0_ISR(void) interrupt 1
{
    char SFRPAGE_SAVE = SFRPAGE; // Save current SFR page
    // Reload Timer 0 (critical region)
    EA = 0; // Disable interrupts
    SFRPAGE = TIMER01_PAGE;
    TH0 = 0xDC; // Load initial value
    TL0 = 0x00;
    EA = 1;                 // Re-enable interrupts
    SFRPAGE = SFRPAGE_SAVE; // Restore SFR page

    // LED flashing code - add this section
    led_flash_counter++;
    if (led_flash_counter >= 20)
    {                          // Adjust this value for faster/slower flashing
        LED = !LED;            // Toggle LED state
        led_flash_counter = 0; // Reset counter
    }

    if (dummy != 0)
    {
        // TDM approach to display RECD (or similar status)
        switch (refresher)
        {
        case 0:
            MSEL1 = 0;
            MSEL0 = 0;
            if (dummy == 1)
                P2 = D;
            else
                P2 = S;
            refresher++;
            break;
        case 1:
            MSEL1 = 0;
            MSEL0 = 1;
            if (dummy == 1)
                P2 = O;
            else
                P2 = E;
            refresher++;
            break;
        case 2:
            MSEL1 = 1;
            MSEL0 = 0;
            P2 = N;
            refresher++;
            break;
        case 3:
            MSEL1 = 1;
            MSEL0 = 1;
            if (dummy == 1)
                P2 = E;
            else
                P2 = T;
            refresher = 0;
            break;
        default:
            break;
        }
    }
} // Timer0_ISR()

//-----------------------------------------------------------------------------------
// SBUF INTERRUPT
//-----------------------------------------------------------------------------------
void ES_ISR(void) interrupt 4
{
    TI0 = 0;
    TB80 = 0; // Only the chosen listener will listen (after sending address byte)

    if (n < 256)
    {
        SBUF0 = fill[n];
        n++;
    }
    else
    {
        dummy = 2;
        LED = 1;
    }
}
