//------------------------------------------------------------------------------------
// Master/Transmitter - C8051F120 UART Multiprocessor Communication
//------------------------------------------------------------------------------------
// Includes
//------------------------------------------------------------------------------------
#include <c8051f120.h> // SFR declarations

//------------------------------------------------------------------------------------
// Global CONSTANTS
//------------------------------------------------------------------------------------
#define SLAVE_ADDRESS 0x05    // Address of the target slave device
#define DATA_SIZE 64          // Size of data block (0x00-0x3F)

// Display codes for a 7 Segment display
#define S 0x24
#define E 0x30
#define N 0x6A
#define D 0x42
#define O 0x72
#define T 0x78

// State definitions
#define IDLE      0
#define FILLING   1
#define SENDING   2
#define COMPLETE  3

//------------------------------------------------------------------------------------
// Global VARIABLES
//------------------------------------------------------------------------------------
unsigned char xdata data_block[DATA_SIZE];  // Data block for transmission
unsigned char state = IDLE;                 // Current state
unsigned char data_index = 0;               // Current data index
bit transmit_ready = 1;                     // Flag indicating transmitter is ready

sbit LED = P1^6;                            // Green LED: '1' = ON; '0' = OFF
sbit SW1 = P0^2;                            // Switch 1: '0' = pressed, '1' = not pressed

//------------------------------------------------------------------------------------
// Function PROTOTYPES
//------------------------------------------------------------------------------------
void Init_Device(void);
void Oscillator_Init(void);
void Port_IO_Init(void);
void Timer_Init(void);
void UART_Init(void);
void Interrupts_Init(void);
void LED_Init(void);
void Fill_Data_Block(void);
void Start_Transmission(void);
void Display_Status(unsigned char status);

//------------------------------------------------------------------------------------
// Interrupt Service Routines
//------------------------------------------------------------------------------------

//------------------------------------------------------------------------------------
// Timer0_ISR
//------------------------------------------------------------------------------------
// Used for timing and state transitions
//
void Timer0_ISR(void) interrupt 1
{
    TF0 = 0;                       // Clear Timer0 overflow flag
    
    if(state == FILLING) {
        Fill_Data_Block();         // Continue filling data block
        if(data_index >= DATA_SIZE) {
            state = SENDING;       // Move to sending state when data is filled
            data_index = 0;        // Reset index for sending
        }
    }
}

//------------------------------------------------------------------------------------
// ES_ISR
//------------------------------------------------------------------------------------
// UART Interrupt Service Routine - Handles transmission completion
//
void ES_ISR(void) interrupt 4
{
    if(TI0) {
        TI0 = 0;                   // Clear transmit interrupt flag
        transmit_ready = 1;        // Set transmit ready flag
        
        if(state == SENDING) {
            if(data_index < DATA_SIZE) {
                Start_Transmission(); // Continue sending next byte
            }
            else {
                state = COMPLETE;  // All bytes have been sent
                Display_Status(state);
            }
        }
    }
}

//------------------------------------------------------------------------------------
// EX0_ISR
//------------------------------------------------------------------------------------
// External Interrupt 0 Service Routine - Button press to start the process
//
void EX0_ISR(void) interrupt 0
{
    if(state == IDLE) {
        state = FILLING;           // Start filling data
        data_index = 0;            // Initialize data index
        LED = 1;                   // Turn on LED to indicate operation
        Display_Status(state);
    }
    else if(state == COMPLETE) {
        state = IDLE;              // Reset to idle state
        LED = 0;                   // Turn off LED
        Display_Status(state);
    }
}

//------------------------------------------------------------------------------------
// MAIN Routine
//------------------------------------------------------------------------------------
void main(void)
{
    // Disable watchdog timer
    WDTCN = 0xde;
    WDTCN = 0xad;
    
    // Initialize device
    Init_Device();
    
    // Enable global interrupts
    EA = 1;
    
    // Set the appropriate SFR page for operations
    SFRPAGE = LEGACY_PAGE;
    
    // Initial display
    Display_Status(state);
    
    // Main loop
    while(1) {
        // Wait for interrupts to drive the state machine
    }
}

//------------------------------------------------------------------------------------
// Fill_Data_Block
//------------------------------------------------------------------------------------
// Fills the data block with values from 0x00 to 0x3F
//
void Fill_Data_Block(void)
{
    if(data_index < DATA_SIZE) {
        data_block[data_index] = data_index;
        data_index++;
    }
}

//------------------------------------------------------------------------------------
// Start_Transmission
//------------------------------------------------------------------------------------
// Initiates transmission of the next byte in the data block
//
void Start_Transmission(void)
{
    char SFRPAGE_SAVE = SFRPAGE;   // Save current SFR page
    
    SFRPAGE = UART0_PAGE;
    
    if(transmit_ready) {
        transmit_ready = 0;        // Clear ready flag
        
        if(data_index == 0) {      // If first byte (address)
            TB80 = 1;              // Set 9th bit for address
            SBUF0 = SLAVE_ADDRESS; // Send slave address
        }
        else {                      // Data bytes
            TB80 = 0;              // Clear 9th bit for data
            SBUF0 = data_block[data_index - 1]; // Send data byte
        }
        data_index++;
    }
    
    SFRPAGE = SFRPAGE_SAVE;       // Restore SFR page
}

//------------------------------------------------------------------------------------
// Display_Status
//------------------------------------------------------------------------------------
// Updates display or indicators based on current state
//
void Display_Status(unsigned char status)
{
    switch(status) {
        case IDLE:
            // Display nothing or standby indicator
            LED = 0;
            break;
        case FILLING:
            // Indicate filling operation
            LED = 1;
            break;
        case SENDING:
            // Indicate sending operation
            LED = 1;
            break;
        case COMPLETE:
            // Indicate completion
            LED = 1;
            break;
        default:
            LED = 0;
    }
}

//------------------------------------------------------------------------------------
// Init_Device
//------------------------------------------------------------------------------------
// Master initialization function
//
void Init_Device(void)
{
    Oscillator_Init();
    Port_IO_Init();
    Timer_Init();
    UART_Init();
    Interrupts_Init();
    LED_Init();
}

//------------------------------------------------------------------------------------
// Oscillator_Init
//------------------------------------------------------------------------------------
// Configure the external oscillator to use 22.1184 MHz frequency
//
void Oscillator_Init(void)
{
    int i = 0;
    SFRPAGE = CONFIG_PAGE;
    
    // Step 1: Enable the external oscillator
    OSCXCN = 0x67;
    
    // Step 2: Wait 1ms for initialization
    for(i = 0; i < 3000; i++);
    
    // Step 3: Poll for XTLVLD => '1'
    while((OSCXCN & 0x80) == 0);
    
    // Step 4: Switch the system clock to the external oscillator
    CLKSEL = 0x01;
    OSCICN = 0x00;
}

//------------------------------------------------------------------------------------
// Port_IO_Init
//------------------------------------------------------------------------------------
// Configure I/O ports
//
void Port_IO_Init(void)
{
    // P0.0 - TX0 (UART0), Push-Pull, Digital
    // P0.1 - RX0 (UART0), Open-Drain, Digital
    // P0.2 - INT0 (Tmr0), Open-Drain, Digital
    SFRPAGE = CONFIG_PAGE;
    
    XBR0 = 0x04;      // Enable UART0 (TX/RX on P0.0/P0.1)
    XBR1 = 0x04;      // Enable INT0 (P0.2)
    XBR2 = 0x40;      // Enable crossbar and weak pull-ups
    
    P0MDOUT |= 0x01;  // Set P0.0 (TX) to push-pull
}


//------------------------------------------------------------------------------------
// Timer_Init
//------------------------------------------------------------------------------------
// Initialize Timer 0 and Timer 1
//
void Timer_Init(void)
{
    char SFRPAGE_SAVE = SFRPAGE;
    SFRPAGE = TIMER01_PAGE;
    
    // Configure Timer 0 for state machine timing
    TMOD |= 0x01;     // Timer 0 in 16-bit mode
    TH0 = 0xDC;       // Initialize Timer 0 high byte
    TL0 = 0x00;       // Initialize Timer 0 low byte
    TR0 = 1;          // Start Timer 0
    
    // Configure Timer 1 for UART baud rate generation
    TMOD |= 0x20;     // Timer 1 in 8-bit auto-reload mode
    
    // For 9600 baud with 22.1184MHz crystal:
    // TH1 = 256 - ((22118400 / 384) / 9600) = 256 - 6 = 250 = 0xFA
    TH1 = 0xFA;
    TL1 = 0xFA;
    TR1 = 1;          // Start Timer 1
    
    SFRPAGE = SFRPAGE_SAVE;
}

//------------------------------------------------------------------------------------
// UART_Init
//------------------------------------------------------------------------------------
// Initialize the UART for 9-bit multiprocessor communication
//
void UART_Init(void)
{
    char SFRPAGE_SAVE = SFRPAGE;
    SFRPAGE = UART0_PAGE;
    
    SCON0 = 0xF0;     // Mode 3, 9-bit UART, enable reception
    /*
     * SM00 = 1 - Serial Mode bit 0
     * SM10 = 1 - Serial Mode bit 1, Mode 3 (9-bit UART, variable baud rate)
     * SM20 = 1 - Multiprocessor Communications enabled
     * REN0 = 1 - UART0 reception enabled
     * TB80 = 0 - 9th bit to transmit (set before each transmission)
     * RB80 = 0 - 9th bit received
     * TI0  = 0 - Transmit interrupt flag (set when byte is transmitted)
     * RI0  = 0 - Receive interrupt flag (set when byte is received)
     */
    
    SFRPAGE = SFRPAGE_SAVE;
}

//------------------------------------------------------------------------------------
// Interrupts_Init
//------------------------------------------------------------------------------------
// Initialize and enable interrupts
//
void Interrupts_Init(void)
{
    IE = 0x93;        // Enable EA, ES0, ET0, EX0
    /*
     * EA  = 1 - Global interrupt enable
     * ES0 = 1 - Enable UART0 interrupt
     * ET0 = 1 - Enable Timer 0 interrupt
     * EX0 = 1 - Enable External 0 interrupt
     */
    
    IP = 0x10;        // High priority for UART interrupt
    /*
     * PS0 = 1 - UART0 interrupt high priority
     */
    
    TCON = 0x05;      // Edge-triggered INT0, start Timer 0
    /*
     * IT0 = 1 - INT0 edge-triggered
     * TR0 = 1 - Timer 0 run control bit
     */
}

//------------------------------------------------------------------------------------
// LED_Init
//------------------------------------------------------------------------------------
// Initialize LED output
//
void LED_Init(void)
{
    P1MDOUT |= 0x40;  // Configure P1.6 as push-pull output for LED
    LED = 0;          // Turn off LED initially
}