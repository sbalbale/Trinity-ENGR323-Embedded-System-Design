// include the library code:
#include <LiquidCrystal.h>

// initialize the library by associating any needed LCD interface pin
// with the arduino pin number it is connected to
// LCD (4-bit data + RS/E)
const uint8_t LCD_RS = 8;
const uint8_t LCD_E = 9;
const uint8_t LCD_D4 = 4;
const uint8_t LCD_D5 = 5;
const uint8_t LCD_D6 = 6;
const uint8_t LCD_D7 = 7;
// LiquidCrystal lcd(LCD_RS, LCD_E, LCD_D0, LCD_D1, LCD_D2, LCD_D3, LCD_D4, LCD_D5, LCD_D6, LCD_D7);
LiquidCrystal lcd(LCD_RS, LCD_E, LCD_D4, LCD_D5, LCD_D6, LCD_D7);


void setup() {
  // set up the LCD's number of columns and rows:
  lcd.begin(16, 2, LCD_5x10DOTS);
  // Print a message to the LCD.
  lcd.print("hello, world!");
}

void loop() {
  // set the cursor to column 0, line 1
  // (note: line 1 is the second row, since counting begins with 0):
  lcd.setCursor(0, 1);
  // print the number of seconds since reset:
  lcd.print(millis() / 1000);
  // lcd.print("hello, world!");

  // // Turn off the display:
  // lcd.noDisplay();
  // delay(500);
  // // Turn on the display:
  // lcd.display();
  // delay(500);
}

