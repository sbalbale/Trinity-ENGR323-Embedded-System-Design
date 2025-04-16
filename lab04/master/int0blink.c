#include <c8051f120.h>                    // SFR declarations

sbit LED = P1^6;                         // LED on P1.6

// Function Prototypes
void PORT_Init(void);
void Ext0_Init(void);

void main(void)
{
    // Disable watchdog timer
    WDTCN = 0xde;
    WDTCN = 0xad;

    SFRPAGE = CONFIG_PAGE;               // Switch to configuration page
    PORT_Init();
    Ext0_Init();                         // Initialize External Interrupt 0

    EA = 1;                              // Enable global interrupts

    while(1)
    {
        // Main loop does nothing; LED toggling occur in Interrupt
    }
}

void PORT_Init(void)
{
    // Enable Crossbar and weak pull-ups.
    XBR2 = 0x40;
    
    // Configure LED pin (P1.6) as push-pull output.
    P1MDOUT |= 0x40;                     // 0x40 = 0100 0000; bit6 => LED
}

void Ext0_Init(void)
{
    IT0 = 1;                             // Configure INT0 as edge triggered
    EX0 = 1;                             // Enable External Interrupt 0
}

// External Interrupt 0 Service Routine
void INT0_ISR(void) interrupt 0
{
    LED = ~LED;                          // Toggle LED state
}