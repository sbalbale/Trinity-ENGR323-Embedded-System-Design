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