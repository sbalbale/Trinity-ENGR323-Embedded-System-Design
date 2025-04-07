// Receiver (slave) Configuration Code that allows multiprocessor communications via universal asynchronous receiver and transmitter (UART)
// AUTH: Nikolay A. Atanasov
// DATE: 08 NOV 2006
//
// Engineering Department
// Trinity College
//

//------------------------------------------------------------------------------------
// Includes
//------------------------------------------------------------------------------------
#include <c8051f120.h> // SFR declarations

//-----------------------------------------------------------------------------
// 16-bit SFR Definitions
//-----------------------------------------------------------------------------

//------------------------------------------------------------------------------------
// Global CONSTANTS
//------------------------------------------------------------------------------------
#define ADDRESS 0x05  // Slave Address
#define DATA_SIZE 256 // The size of the transmitted data

// Letter codes for a 7 Segment display
#define R 0x08
#define E 0x30
#define C 0x72

#define D 0x42
#define N 0x6A

// Number codes for an active-low 7 Segment display
#define ZERO 0x01
#define ONE 0x4F
#define TWO 0x12
#define THREE 0x06
#define FOUR 0x4C
#define FIVE 0x24
#define SIX 0x60
#define SEVEN 0x0F
#define EIGHT 0x00
#define NINE 0x0C
#define OFF 0xFF

sbit LED = P1 ^ 6;   // green LED: '1' = ON; '0' = OFF
sbit MSEL1 = P1 ^ 5; // Multiplexer Select bits
sbit MSEL0 = P1 ^ 4;

//------------------------------------------------------------------------------------
// Global VARIABLES
//------------------------------------------------------------------------------------
unsigned char xdata ram_block[DATA_SIZE]; // Predefined RAM block to store DATA
short count = 0;                          // Counts the number of bytes received
short interrupt_count = 0;                // Counts the number of Timer 0 overflows
short refresher = 0;                      // Remembers which digit should be refreshed next
bit RECD_flag = 0;                        // Received flag
bit END_flag = 0;                         // End flag

unsigned char digit_one = OFF;   // Holds the binary code representation for digit one
unsigned char digit_two = OFF;   // Holds the binary code representation for digit two
unsigned char digit_three = OFF; // Holds the binary code representation for digit three

//------------------------------------------------------------------------------------
// Function PROTOTYPES
//------------------------------------------------------------------------------------

// Support Subroutines
unsigned char BCD_7SEG(unsigned char digit);
void Receive_Toggle(void); // Toggle Receive Mode ON or OFF
void Toggle_T0(void);      // Display Data stored in RAM_BLOCK sequentially
void clear_display(void);  // Clears the display
void Display(void);

// Interrupt Service Routines
void EX0_ISR(void);
void Timer0_ISR(void); // Timer 0 Overflow Interrupt Service Routine
void ES_ISR(void);     // Serial Interrupt Service Routine

//------------------------------------------------------------------------------------
// Initialization Subroutines
//------------------------------------------------------------------------------------
void Init_Device(void);
void Timer_Init(void);
void UART_Init(void); // Set up Serial Port Control Register
void Port_IO_Init(void);
void Oscillator_Init(void);
void Interrupts_Init(void); // Set up Serial Interrupt
void Address_Init(void);
void LED_Init(void);

//------------------------------------------------------------------------------------
// MAIN Routine
//------------------------------------------------------------------------------------
void main(void)
{
    // Receiver:
    // ES_ISR() is called only when RI = 1
    // when a byte is received RI = 1 iff RB8 (9th) = 1 AND SM2 = 1
    // address byte: xxxxxxxx1 (9th) -> If being addressed set SM2 = 0 to receive data!
    // data byte: xxxxxxxx0 (9th) -> Does not interrupt any slave when SM2 = 1

    // Disable watchdog timer
    WDTCN = 0xde;
    WDTCN = 0xad;

    SFRPAGE = CONFIG_PAGE; // Switch to configuration page

    // Configure UART to allow multiprocessor communication at 9600 baud rate
    // 1. Configure SCON to operate in Mode 3 (multiprocessor variable mode)
    // 2. Configure Baud Rate by setting up Timer 1
    Init_Device();

    EA = 1; // Enable global interrupts

    SFRPAGE = LEGACY_PAGE; // Page to sit in for now

    while (1)
        ; // Waiting loop
}

//-----------------------------------------------------------------------------
// Support Subroutines
//-----------------------------------------------------------------------------

//------------------------------------------------------------------------------------
// BCD_7SEG
//------------------------------------------------------------------------------------
// Converts a decimal digit (0-9) into the binary code representation for an active-low 7-segment display.
unsigned char BCD_7SEG(unsigned char digit)
{
    unsigned char result;
    switch (digit)
    {
    case 0:
        result = ZERO;
        break;
    case 1:
        result = ONE;
        break;
    case 2:
        result = TWO;
        break;
    case 3:
        result = THREE;
        break;
    case 4:
        result = FOUR;
        break;
    case 5:
        result = FIVE;
        break;
    case 6:
        result = SIX;
        break;
    case 7:
        result = SEVEN;
        break;
    case 8:
        result = EIGHT;
        break;
    case 9:
        result = NINE;
        break;
    default:
        result = OFF;
    }
    return result;
} // BCD_7SEG()

//------------------------------------------------------------------------------------
// Receive_Toggle
//------------------------------------------------------------------------------------
// Toggles the SM2 bit in the SCON register to turn slave receiving on or off.
void Receive_Toggle()
{
    char SFRPAGE_SAVE = SFRPAGE; // Save current SFR page
    SFRPAGE = UART0_PAGE;
    SM20 ^= 1;              // Toggle the state of SM20
    SFRPAGE = SFRPAGE_SAVE; // Restore SFR page
} // Receive_Toggle()

//------------------------------------------------------------------------------------
// Toggle_T0
//------------------------------------------------------------------------------------
// Toggles Timer 0 between running and off.
void Toggle_T0(void)
{
    char SFRPAGE_SAVE = SFRPAGE; // Save current SFR page
    SFRPAGE = TIMER01_PAGE;
    TR0 ^= 1;               // Toggle Timer 0 run control
    ET0 ^= 1;               // Toggle Timer 0 overflow interrupt
    SFRPAGE = SFRPAGE_SAVE; // Restore SFR page
} // Toggle_T0()

//------------------------------------------------------------------------------------
// clear_display
//------------------------------------------------------------------------------------
// Resets the seven-segment display.
void clear_display(void)
{
    char SFRPAGE_SAVE = SFRPAGE; // Save current SFR page
    SFRPAGE = TIMER01_PAGE;
    TR0 &= 0;               // Turn off Timer 0 run control
    ET0 &= 0;               // Turn off Timer 0 overflow interrupt
    SFRPAGE = SFRPAGE_SAVE; // Restore SFR page
    RECD_flag = 0;
    END_flag = 0;
    P2 = OFF;
} // clear_display()

//------------------------------------------------------------------------------------
// Display
//------------------------------------------------------------------------------------
// Refreshes the display with the appropriate value based on the current mode.
void Display(void)
{
    switch (refresher)
    {
    case 0: // MSB
        MSEL1 = 0;
        MSEL0 = 0;
        if (RECD_flag)
            P2 = R;
        else
            P2 = OFF;
        refresher++;
        break;
    case 1:
        MSEL1 = 0;
        MSEL0 = 1;
        if (RECD_flag || END_flag)
            P2 = E;
        else
            P2 = digit_three;
        refresher++;
        break;
    case 2:
        MSEL1 = 1;
        MSEL0 = 0;
        if (RECD_flag)
            P2 = C;
        else if (END_flag)
            P2 = N;
        else
            P2 = digit_two;
        refresher++;
        break;
    case 3:
        MSEL1 = 1;
        MSEL0 = 1;
        if (RECD_flag || END_flag)
            P2 = D;
        else
            P2 = digit_one;
        refresher = 0;
        break;
    default:
        break;
    }
} // Display()

//------------------------------------------------------------------------------------
// Interrupt Service Routines
//------------------------------------------------------------------------------------

// EX0_ISR: Starts the display of data stored in ram_block by setting appropriate flags.
void EX0_ISR(void) interrupt 0
{
    RECD_flag = 0; // Start displaying data
    END_flag = 0;
} // EX0_ISR()

//------------------------------------------------------------------------------------
// Timer0_ISR
//------------------------------------------------------------------------------------
// Refreshes the display every 5ms and, every 1 second, sends the next piece of data stored in ram_block.
void Timer0_ISR(void) interrupt 1
{
    short letter;
    char SFRPAGE_SAVE = SFRPAGE; // Save current SFR page

    // Reload Timer 0 to start counting over (critical region)
    EA = 0; // Disable interrupts
    SFRPAGE = TIMER01_PAGE;
    TH0 = 0xDC; // Load initial value
    TL0 = 0x00;
    EA = 1;                 // Re-enable interrupts
    SFRPAGE = SFRPAGE_SAVE; // Restore SFR page

    interrupt_count++; // Increase the interrupt count

    if (interrupt_count != 200) // If 1 sec has not yet passed
    {
        Display();
        return;
    }
    else // 1 sec has passed
    {
        if (RECD_flag || END_flag)
        {
            interrupt_count = 0;
            Display(); // Display RECD or END
            return;
        }
        if (count == DATA_SIZE) // All data has been displayed
        {
            END_flag = 1; // Display END
            count = 0;
            interrupt_count = 0;
            return;
        }
        letter = ram_block[count];         // Get next character
        digit_one = BCD_7SEG(letter % 10); // LSB
        digit_two = BCD_7SEG((letter % 100) / 10);
        digit_three = BCD_7SEG(letter / 100); // MSB
        count++;
        interrupt_count = 0; // Reset counter
        Display();
    }
} // Timer0_ISR()

//------------------------------------------------------------------------------------
// ES_ISR
//------------------------------------------------------------------------------------
// Serial Interrupt Service Routine called only for address bytes (9th bit RB8 = 1) matching the slave address.
void ES_ISR(void) interrupt 4
{
    char SFRPAGE_SAVE = SFRPAGE; // Save current SFR page

    RI0 = 0; // Clear RI flag
    LED = 1;

    // RECEIVER operation
    if (SM20 == 1 && SBUF0 != ADDRESS) // Not addressed
        return;
    if (SM20 && SBUF0 == ADDRESS) // Being addressed
    {
        Receive_Toggle(); // Turn on Receiving Mode
        clear_display();  // Clear the display
        count = 0;        // Reset RAM block pointer
    }
    else // Receiving data
    {
        ram_block[count] = SBUF0; // Store received data
        count++;                  // Move to next byte
        if (count == DATA_SIZE)   // If all data received
        {
            Receive_Toggle(); // Turn off Receiving Mode
            count = 0;        // Reset count
            RECD_flag = 1;    // Indicate data reception complete
            Toggle_T0();      // Start Timer 0 for display
        }
    }

    SFRPAGE = SFRPAGE_SAVE; // Restore SFR page

    // TRANSMITTER operations (commented out here)
    // Invoke ISR to write #00 to #FF to RAM and display DONE,
    // then specify receiver and start transmission, and display SENT.
} // ES_ISR()

//-----------------------------------------------------------------------------
// Initialization Subroutines
//-----------------------------------------------------------------------------

// Init_Device: Initializes all peripherals.
void Init_Device(void)
{
    Timer_Init();
    UART_Init();
    Port_IO_Init();
    Oscillator_Init();
    Interrupts_Init();
    Address_Init();
    LED_Init();
} // Init_Device()

//-----------------------------------------------------------------------------
// Timer_Init
//-----------------------------------------------------------------------------
void Timer_Init(void)
{
    SFRPAGE = TIMER01_PAGE;
    TMOD = 0x21; // Timer 1 in 8-bit auto-reload mode; Timer 0 in 16-bit mode

    // Configure Timer 0 for a 1-second interval using a TDM approach
    TH0 = 0xDC; // Load initial value
    TL0 = 0x00;

    // Configure Timer 1 for 9600 baud rate
    TH1 = 0xFA;  // Load initial value
    TCON = 0x41; // Enable Timer 1 run control; configure INT0 as edge triggered
} // Timer_Init()

//-----------------------------------------------------------------------------
// UART_Init
//-----------------------------------------------------------------------------
void UART_Init(void)
{
    SFRPAGE = UART0_PAGE;
    SCON0 = 0xF0;
    /*
     * SM00 = 1, SM01 = 1 selects Mode 3 (multiprocessor variable mode)
     * SM20 = 1 enables multiprocessor communications (interrupt only when 9th bit set)
     * REN0 = 1 enables UART0 reception
     */
} // UART_Init()

//-----------------------------------------------------------------------------
// Port_IO_Init
//-----------------------------------------------------------------------------
void Port_IO_Init()
{
    // P0.0 - TX0, P0.1 - RX0, P0.2 - INT0, P0.3 - Unassigned
    SFRPAGE = CONFIG_PAGE;
    XBR0 = 0x04; // Enable UART0 I/O (TX on P0.0, RX on P0.1)
    XBR1 = 0x04; // Enable /INT0 input (P0.2)
    XBR2 = 0x40; // Enable weak pull-ups
} // Port_IO_Init()

//-----------------------------------------------------------------------------
// Oscillator_Init
//-----------------------------------------------------------------------------
void Oscillator_Init()
{
    int i = 0;
    SFRPAGE = CONFIG_PAGE;
    OSCXCN = 0x67; // Enable external oscillator (22.1184 MHz)
    for (i = 0; i < 3000; i++)
        ; // Wait for initialization
    while ((OSCXCN & 0x80) == 0)
        ;          // Wait for XTLVLD flag
    CLKSEL = 0x01; // Switch system clock to external oscillator
    OSCICN = 0x00;
} // Oscillator_Init()

//-----------------------------------------------------------------------------
// Interrupts_Init
//-----------------------------------------------------------------------------
void Interrupts_Init()
{
    IE = 0x11; // Enable UART0 and external interrupt 0
    IP = 0x10; // Set UART0 interrupt priority
} // Interrupts_Init()

//-----------------------------------------------------------------------------
// Address_Init
//-----------------------------------------------------------------------------
void Address_Init(void)
{
    SADDR0 = ADDRESS; // Set slave address
    SADEN0 = 0xFF;    // Check all bits of the address
} // Address_Init()

//------------------------------------------------------------------------------------
// LED_Init
//------------------------------------------------------------------------------------
void LED_Init(void)
{
    P1MDOUT |= 0x40;
    LED = 0;
} // LED_Init()
