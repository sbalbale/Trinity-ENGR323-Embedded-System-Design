//------------------------------------------------------------------------------------
// Music.c - Fixed version to properly play a melody
//------------------------------------------------------------------------------------
#include <c8051f120.h> // SFR declarations

//-----------------------------------------------------------------------------
// 16-bit SFR Definitions for 'F12x
//-----------------------------------------------------------------------------

sfr16 RCAP3 = 0xCA; // Timer3 reload value
sfr16 TMR3 = 0xCC;  // Timer3 counter

//------------------------------------------------------------------------------------
// Global CONSTANTS
//------------------------------------------------------------------------------------

#define SYSCLK 3062500 // approximate SYSCLK frequency in Hz

sbit LED = P1 ^ 6;     // green LED: '1' = ON; '0' = OFF
sbit SPEAKER = P1 ^ 4; // tone output: '1' = ON; '0' = OFF

// Note frequencies (Hz)
#define NOTE_C  220
#define NOTE_D  247
#define NOTE_E  277
#define NOTE_F  294
#define NOTE_G  330
#define NOTE_A  370
#define NOTE_B  415
#define NOTE_H  440  // High C / C2

// Mary had a little lamb melody
#define ML_SIZE 26
char Mary_Lamb[ML_SIZE] = {'E', 'D', 'C', 'D', 'E', 'E', 'E', 
                           'D', 'D', 'D', 'E', 'G', 'G', 
                           'E', 'D', 'C', 'D', 'E', 'E', 'E',
                           'E', 'D', 'D', 'E', 'D', 'C'}; // complete melody
short ML_length[ML_SIZE] = {2, 2, 2, 2, 2, 2, 4, 
                           2, 2, 4, 2, 2, 4, 
                           2, 2, 2, 2, 2, 2, 4, 
                           2, 2, 4, 2, 2, 4};     // relative duration

// Global variables
unsigned short note_idx = 0;      // index for current note
unsigned short tone_counter = 0;  // counter for tone generation
unsigned short duration_counter = 0; // counter for note duration
unsigned short current_frequency;    // frequency of current note
unsigned short current_duration;     // duration of current note
bit playing_tone = 1;               // flag to indicate if tone should be playing

//------------------------------------------------------------------------------------
// Function PROTOTYPES
//------------------------------------------------------------------------------------
void PORT_Init(void);
void Timer3_Init(int counts);
void Timer3_ISR(void);
void delay_ms(unsigned int ms);
void playNote(char note, short duration);
unsigned short getNoteFrequency(char note);

//------------------------------------------------------------------------------------
// MAIN Routine
//------------------------------------------------------------------------------------
void main(void)
{
   // disable watchdog timer
   WDTCN = 0xde;
   WDTCN = 0xad;

   SFRPAGE = CONFIG_PAGE; // Switch to configuration page
   PORT_Init();

   SFRPAGE = LEGACY_PAGE; // Page to sit in for now
   EA = 1;                // enable global interrupts

   // Play the melody note by note
   for (note_idx = 0; note_idx < ML_SIZE; note_idx++) {
      playNote(Mary_Lamb[note_idx], ML_length[note_idx]);
   }

   // After playing the melody, stop
   TR3 = 0;  // Stop the timer
   SPEAKER = 0; // Turn off speaker
   
   while(1) {
      // Flash LED to indicate we're done
      LED = ~LED;
      delay_ms(500);
   }
}

//------------------------------------------------------------------------------------
// playNote - Plays a single note for the specified duration
//------------------------------------------------------------------------------------
void playNote(char note, short duration) {
   unsigned short freq = getNoteFrequency(note);
   
   // If it's a valid frequency
   if (freq > 0) {
      // Set up timer for this frequency
      SFRPAGE = TMR3_PAGE;
      Timer3_Init(SYSCLK / 12 / freq / 2);
      
      // Play for the specified duration (250ms per duration unit)
      delay_ms(250 * duration);
      
      // Brief pause between notes to create separation
      TR3 = 0;  // Stop timer
      SPEAKER = 0; // Turn off speaker
      delay_ms(50);
   }
}

//------------------------------------------------------------------------------------
// getNoteFrequency - Returns the frequency for a given note character
//------------------------------------------------------------------------------------
unsigned short getNoteFrequency(char note) {
   switch (note) {
      case 'C': return NOTE_C;
      case 'D': return NOTE_D;
      case 'E': return NOTE_E;
      case 'F': return NOTE_F;
      case 'G': return NOTE_G;
      case 'A': return NOTE_A;
      case 'B': return NOTE_B;
      case 'H': return NOTE_H;
      default: return 0;  // Invalid note
   }
}

//------------------------------------------------------------------------------------
// delay_ms - Simple delay function
//------------------------------------------------------------------------------------
void delay_ms(unsigned int ms) {
   unsigned int i, j;
   for (i = 0; i < ms; i++) {
      for (j = 0; j < 100; j++);  // Adjust this for accurate timing
   }
}

//------------------------------------------------------------------------------------
// PORT_Init
//------------------------------------------------------------------------------------
void PORT_Init(void)
{
   XBR2 = 0x40;     // Enable crossbar and weak pull-ups
   P1MDOUT |= 0x50; // enable P1.6 (LED) and P1.4 (SPEAKER) as push-pull outputs
}

//------------------------------------------------------------------------------------
// Timer3_Init
//------------------------------------------------------------------------------------
void Timer3_Init(int counts)
{
   TMR3CN = 0x00;   // Stop Timer3; Clear TF3; use SYSCLK/12 as timebase
   RCAP3 = -counts; // Init reload values
   TMR3 = 0xffff;   // set to reload immediately
   EIE2 |= 0x01;    // enable Timer3 interrupts
   TR3 = 1;         // start Timer3
}

//------------------------------------------------------------------------------------
// Timer3_ISR
//------------------------------------------------------------------------------------
void Timer3_ISR(void) interrupt 14
{
   TF3 = 0;         // clear TF3
   SPEAKER = ~SPEAKER; // toggle speaker to generate tone
   
   // Blink LED at slower rate for visual feedback
   tone_counter++;
   if (tone_counter >= 100) {
      LED = ~LED;
      tone_counter = 0;
   }
}