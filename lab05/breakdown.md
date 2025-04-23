Below is a complete wiring guide and Arduino sketch for your UNO R4 WiFi. It will drive a DC motor via an SN754410 H-bridge, measure its speed with an 80-pulse optical encoder, and show the RPM on a 16×2 HD44780-compatible LCD (e.g. HDM16216H-B).

---

## 1. Wiring

### 1.1 SN754410 H-Bridge (pins refer to the 16-pin DIP package)
1. **Logic supply (VCC1, pin 7)** → Arduino 5 V citeturn3file0  
2. **Motor supply (VCC2, pin 6)** → battery + (e.g. 9 V) citeturn3file0  
3. **Grounds (all GND pins & tab)** → Arduino GND (tie battery GND here too)  
4. **1,2 Enable (pin 1)** → Arduino D5 (PWM)  
5. **Input 1A (pin 2)** → Arduino D3  
6. **Input 2A (pin 5)** → Arduino D4  
7. **Output 1Y (pin 3)** → Motor +  
8. **Output 2Y (pin 4)** → Motor –  

> When EN is high, driver outputs follow 1A/2A; EN low tristates them citeturn2file4.  

### 1.2 DC Motor & Encoder
1. **Motor terminals** to SN754410 1Y/2Y.  
2. **Encoder LED**: +5 V → 220 Ω → encoder LED anode; LED cathode → GND.  
3. **Encoder output (phototransistor)** → Arduino D2 (INT0), configure `INPUT_PULLUP` citeturn2file3.  

### 1.3 LCD (HDM16216H-B)
1. **Pin 1 VSS** → GND  
2. **Pin 2 VDD** → +5 V  
3. **Pin 3 VL (contrast)** → wiper of 10 K Ω pot (ends to +5 V and GND) citeturn2file1  
4. **Pin 4 RS** → D7  
5. **Pin 5 R/W** → GND  
6. **Pin 6 E** → D8  
7. **Pin 11 D4** → D9  
8. **Pin 12 D5** → D10  
9. **Pin 13 D6** → D11  
10. **Pin 14 D7** → D12  
11. **(Optional backlight)** Pin 15 → +5 V (via 220 Ω), Pin 16 → GND  

> You’ll run the display in 4-bit mode; RW tied low means no busy-flag reads are needed citeturn2file1.  

### 1.4 Power rails
- Tie the Arduino’s 5 V and GND to your breadboard rails.  
- Tie the motor battery GND to the same GND rail.  

---

## 2. Arduino Sketch

```cpp
#include <LiquidCrystal.h>

// LCD pins: RS, E, D4, D5, D6, D7
LiquidCrystal lcd(7, 8, 9, 10, 11, 12);

const int pwmPin       = 5;   // SN754410 EN (PWM)
const int dirPin1      = 3;   // SN754410 1A
const int dirPin2      = 4;   // SN754410 2A
const int encoderPin   = 2;   // INT0
const int potPin       = A0;  // speed adjust (optional)
const int pulsesPerRev = 80;  // encoder counts per rev citeturn2file3

volatile unsigned long pulseCount     = 0;
unsigned long          lastPulseCount = 0;
unsigned long          lastMillis     = 0;
const unsigned long    interval       = 1000; // measurement period (ms)

void countPulse() {
  pulseCount++;
}

void setup() {
  // H-bridge control
  pinMode(pwmPin,  OUTPUT);
  pinMode(dirPin1, OUTPUT);
  pinMode(dirPin2, OUTPUT);
  // fix forward direction:
  digitalWrite(dirPin1, HIGH);
  digitalWrite(dirPin2, LOW);

  // encoder input
  pinMode(encoderPin, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(encoderPin), countPulse, RISING);

  // LCD init
  lcd.begin(16, 2);
  lcd.print("RPM: --");
}

void loop() {
  // optional: read pot to set speed
  int pwmVal = map(analogRead(potPin), 0, 1023, 0, 255);
  analogWrite(pwmPin, pwmVal);  // PWM drives motor speed citeturn2file5

  // every second, compute and display RPM
  unsigned long now = millis();
  if (now - lastMillis >= interval) {
    noInterrupts();
      unsigned long count = pulseCount - lastPulseCount;
      lastPulseCount = pulseCount;
    interrupts();

    unsigned long rpm = (count * 60000UL) / (pulsesPerRev * interval);

    lcd.setCursor(5, 0);
    lcd.print("    ");      // clear old
    lcd.setCursor(5, 0);
    lcd.print(rpm);

    lastMillis = now;
  }
}
```

**How it works**  
- **PWM** on D5 varies the H-bridge’s enable duty cycle to control motor voltage and speed citeturn2file5.  
- **Direction** is held constant (swap D3/D4 if you ever want to reverse).  
- **Encoder** pulses on D2 are counted in an ISR; once per second we compute  
  \[
    \text{RPM} = \frac{\Delta\text{pulses}\times 60000}{\text{pulsesPerRev}\times\text{interval(ms)}}  
  \]  
  with 80 counts/rev citeturn2file3.  
- **LiquidCrystal** in 4-bit mode displays the result on the LCD citeturn2file1.  

Load this to your Uno R4 WiFi, wire as above, and you’ll have real-time RPM control and readout!