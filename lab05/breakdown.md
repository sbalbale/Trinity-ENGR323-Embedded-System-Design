# Lab 5: DC Motor Control with Arduino Uno R4 WiFis
1. Generates a PWM signal on pin 3 to drive your motor (via an H-bridge).  
2. Reads pulses from the YC-52010 Hall sensor on pin 2 (one pulse per revolution).  
3. Blinks the built-in LED (pin 13) at a rate proportional to the target RPM.  
4. Calculates actual RPM every second.  
5. Displays the target and actual RPM on a 16×2 LCD (HDM16216–based) using the Arduino LiquidCrystal library.  
6. Prints both values to the Serial Monitor at 9600 baud.  
7. Lets you set the “projected” (target) RPM by typing a number into the Serial Monitor.

```cpp
#include <LiquidCrystal.h>

// ── USER CONFIG ───────────────────────────────────────────────────────────────
// Pins
const uint8_t MOTOR_PIN      = 3;   // PWM output (must be a PWM-capable pin)
const uint8_t HALL_PIN       = 2;   // Hall-effect sensor input (INT0)
const uint8_t LED_PIN        = 13;  // Built-in LED pin
const uint8_t LCD_RS         = 8;
const uint8_t LCD_E          = 9;
const uint8_t LCD_D4         = 4;
const uint8_t LCD_D5         = 5;
const uint8_t LCD_D6         = 6;
const uint8_t LCD_D7         = 7;

// Motor characteristics
const uint16_t PULSES_PER_REV = 1;    // adjust if your sensor gives more pulses per revolution
const uint16_t MAX_RPM        = 5000; // maximum expected RPM for mapping

// Measurement
const unsigned long INTERVAL_MS = 1000; // compute RPM every 1000 ms

// ── GLOBALS ───────────────────────────────────────────────────────────────────
LiquidCrystal lcd(LCD_RS, LCD_E, LCD_D4, LCD_D5, LCD_D6, LCD_D7);

volatile uint32_t pulseCount = 0;  // incremented in ISR
uint32_t lastMeasureTime      = 0;
uint16_t targetRPM            = 0;
unsigned long lastBlinkTime   = 0; // Time LED was last toggled
bool ledState                 = LOW; // Current state of the LED

// ── INTERRUPT SERVICE ROUTINE ────────────────────────────────────────────────
void onHallPulse() {
  pulseCount++;
}

// ── LED BLINK FUNCTION ────────────────────────────────────────────────────────
void blinkLed() {
  if (targetRPM == 0) {
    // If target RPM is 0, turn LED off
    if (ledState == HIGH) {
      digitalWrite(LED_PIN, LOW);
      ledState = LOW;
    }
    return;
  }

  // Half–period (ms) = 300000 / targetRPM
  unsigned long interval = 300000UL / targetRPM;
  if (interval == 0) interval = 1;

  unsigned long now = millis();
  if (now - lastBlinkTime >= interval) {
    ledState = !ledState;
    digitalWrite(LED_PIN, ledState);
    lastBlinkTime = now;
  }
}

// ── SETUP ─────────────────────────────────────────────────────────────────────
void setup() {
  // LCD
  lcd.begin(16, 2);
  lcd.print("DC Motor Ctrl");

  // Serial
  Serial.begin(9600);
  Serial.println();
  Serial.println("Enter target RPM and press ↵");

  // Motor PWM pin
  pinMode(MOTOR_PIN, OUTPUT);
  analogWrite(MOTOR_PIN, 0);

  // Hall sensor input with pull-up
  pinMode(HALL_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(HALL_PIN), onHallPulse, RISING);

  // LED pin
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  lastMeasureTime = millis();
}

// ── MAIN LOOP ─────────────────────────────────────────────────────────────────
void loop() {
  // 1) Blink the LED according to target RPM
  blinkLed();

  // 2) Read new target RPM from Serial
  if (Serial.available()) {
    String line = Serial.readStringUntil('\n');
    line.trim();
    if (line.length() > 0) {
      long val = line.toInt();
      if (val >= 0 && val <= MAX_RPM) {
        targetRPM = val;
        uint8_t duty = map(targetRPM, 0, MAX_RPM, 0, 255);
        analogWrite(MOTOR_PIN, duty);
        Serial.print(">> Target set to ");
        Serial.print(targetRPM);
        Serial.println(" RPM");
      } else {
        Serial.println("! Invalid RPM (0–" + String(MAX_RPM) + ")");
      }
    }
  }

  // 3) Every INTERVAL_MS, compute & display actual RPM
  unsigned long now = millis();
  if (now - lastMeasureTime >= INTERVAL_MS) {
    noInterrupts();
    uint32_t pulses = pulseCount;
    pulseCount = 0;
    interrupts();

    uint32_t actualRPM = pulses * 60UL * (1000UL / INTERVAL_MS) / PULSES_PER_REV;

    // Update LCD
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Tgt:");
    lcd.print(targetRPM);
    lcd.print("rpm");
    lcd.setCursor(0, 1);
    lcd.print("Act:");
    lcd.print(actualRPM);
    lcd.print("rpm");

    // Print to Serial
    Serial.print("Target RPM: ");
    Serial.print(targetRPM);
    Serial.print("  |  Actual RPM: ");
    Serial.println(actualRPM);

    lastMeasureTime = now;
  }
}
```

---

### How it works

1. **PWM output**  
   `analogWrite(MOTOR_PIN, duty);` produces an 8-bit (0–255) PWM signal on pin 3 to drive your H-bridge.

2. **RPM sensing**  
   The YC-52010 outputs one pulse per revolution. We count these in an ISR attached to D2.

3. **LED blink**  
   The built-in LED on pin 13 toggles at a rate of `(targetRPM/10)/60` Hz, so faster target speeds blink faster. When `targetRPM` is 0 the LED stays off.

4. **RPM calculation**  
   Each second we atomically read & reset `pulseCount` and compute  
   \[
     \mathrm{RPM} = \frac{\text{pulses}}{\text{pulses/rev}}
                  \times \frac{60\,000\text{ ms}}{\text{interval (ms)}}
   \]

5. **Display**  
   We drive a 16×2 HD44780–compatible LCD with the Arduino `LiquidCrystal` library.

6. **Serial I/O**  
   - Serial 9600 baud.  
   - Type a number in the Serial Monitor and press ↵ to set the target RPM.

---

### Wiring

| **Signal**                | **Module Pin**             | **Arduino Uno R4 WiFi**        |
|---------------------------|----------------------------|---------------------------------|
| **Motor & H-Bridge (SN754410)** |||
| PWM Enable (1,2EN)        | Pin 1                       | D3 (MOTOR_PIN)                  |
| Direction Input (1A)      | Pin 2                       | Tie to 5 V (for fixed direction)|
| Motor+                    | Pin 3 (1Y)                  | → Motor lead +                  |
| Motor–                    | Pin 6 (2Y)                  | → Motor lead –                  |
| VCC₁ (logic)              | Pin 16                      | +5 V                            |
| VCC₂ (motor)              | Pin 8                       | External motor supply (e.g. 9 V)|
| GND                       | Pins 4,5,12,13              | Common GND (Arduino + supply)   |
| **Hall Sensor (YC-52010)** |||
| VCC                       | VCC                         | +5 V                            |
| GND                       | GND                         | GND                             |
| Output                    | OUT                         | D2 (HALL_PIN, INT0)             |
| **LCD (HDM16216 / HD44780)** |||
| VSS                       | Pin 1                       | GND                             |
| VDD                       | Pin 2                       | +5 V                            |
| VO (contrast)             | Pin 3                       | Center of 10 kΩ pot (5 V–GND)   |
| RS                        | Pin 4                       | D8 (LCD_RS)                     |
| RW                        | Pin 5                       | GND                             |
| E                         | Pin 6                       | D9 (LCD_E)                      |
| D4                        | Pin 11                      | D4 (LCD_D4)                     |
| D5                        | Pin 12                      | D5 (LCD_D5)                     |
| D6                        | Pin 13                      | D6 (LCD_D6)                     |
| D7                        | Pin 14                      | D7 (LCD_D7)                     |
| LED+ (backlight)          | Pin 15                      | +5 V (through 220 Ω resistor)   |
| LED– (backlight)          | Pin 16                      | GND                             |
| **Built-in LED**          | —                           | D13 (LED_PIN)                   |

All grounds must be common (Arduino GND, motor supply GND, sensor GND, H-bridge GND, LCD GND).  
Use a 10 kΩ potentiometer between +5 V and GND to feed VO (contrast) on the LCD.  
Ensure your H-bridge VCC₂ matches your motor’s supply voltage.  
