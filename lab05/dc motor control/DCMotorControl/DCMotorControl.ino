#include <LiquidCrystal.h>

// ── USER CONFIG ───────────────────────────────────────────────────────────────
// Pins

// PWM → H-bridge
const uint8_t MOTOR_PIN = 3; // PWM output (must be a PWM-capable pin)

// Hall sensor → INT0
const uint8_t HALL_PIN = 2; // Hall-effect sensor input (INT0) must be D2 for external interrupt

// Built-in LED
const uint8_t LED_PIN = 13; // Built-in LED pin

// LCD (4-bit data + RS/E)
const uint8_t LCD_RS = 8;
const uint8_t LCD_E = 9;
const uint8_t LCD_D4 = 4;
const uint8_t LCD_D5 = 5;
const uint8_t LCD_D6 = 6;
const uint8_t LCD_D7 = 7;

// Motor characteristics
const uint16_t PULSES_PER_REV = 64; // adjust if your sensor gives more pulses per revolution
const uint16_t MAX_RPM = 500;       // maximum expected RPM for mapping

// Measurement
const unsigned long INTERVAL_MS = 1000; // compute RPM every 1000 ms

const float RPM_CALIBRATION_FACTOR = 0.2;

const float KP = 0.8;             // Proportional gain
const float KI = 0.7;             // Integral gain
const float KD = 0.05;            // Derivative gain
const float MAX_INTEGRAL = 400.0; // Anti-windup limit

float integral = 0.0;
int lastError = 0;
uint8_t currentDuty = 0; // Current PWM duty cycle

// ── GLOBALS ───────────────────────────────────────────────────────────────────
LiquidCrystal lcd(LCD_RS, LCD_E, LCD_D4, LCD_D5, LCD_D6, LCD_D7);

volatile uint32_t pulseCount = 0; // incremented in ISR
uint32_t lastMeasureTime = 0;
uint16_t targetRPM = 150;
unsigned long lastBlinkTime = 0; // Time LED was last toggled
bool ledState = LOW;             // Current state of the LED

// ── INTERRUPT SERVICE ROUTINE ────────────────────────────────────────────────
void onHallPulse()
{
  pulseCount++;
}

// ── LED BLINK FUNCTION ────────────────────────────────────────────────────────
void blinkLed()
{
  if (targetRPM == 0)
  {
    // If target RPM is 0, turn LED off and return
    if (ledState == HIGH)
    {
      digitalWrite(LED_PIN, LOW);
      ledState = LOW;
    }
    return;
  }

  // Calculate blink frequency (Hz) = (targetRPM / 10) / 60
  // Calculate period (ms) = 1000 / frequency = 1000 * 60 * 10 / targetRPM = 600000 / targetRPM
  // Half period (for on or off time) = 300000 / targetRPM
  unsigned long blinkInterval = 300000UL / targetRPM; // Time in ms for half cycle (on or off)

  // Prevent division by zero or extremely fast blinking if targetRPM is very high momentarily
  if (blinkInterval == 0)
    blinkInterval = 1; // Minimum interval to prevent issues

  unsigned long now = millis();
  if (now - lastBlinkTime >= blinkInterval)
  {
    ledState = !ledState; // Toggle LED state
    digitalWrite(LED_PIN, ledState);
    lastBlinkTime = now; // Reset the timer
  }
}

// ── SETUP ─────────────────────────────────────────────────────────────────────
void setup()
{
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
  digitalWrite(LED_PIN, LOW); // Start with LED off

  lastMeasureTime = millis();
}

// ── MAIN LOOP ─────────────────────────────────────────────────────────────────
void loop()
{
  // — Blink LED based on target RPM —
  blinkLed();

  // — check for new target RPM from Serial —
  if (Serial.available())
  {
    // read up to the newline, trim off any whitespace
    String line = Serial.readStringUntil('\n');
    line.trim();
    if (line.length() > 0)
    {
      long val = line.toInt();
      if (val >= 0 && val <= MAX_RPM)
      {
        targetRPM = val;
        // update PWM duty
        uint8_t duty;
        if (targetRPM == 0)
        {
          duty = 0;
        }
        else
        {
          // Minimum duty needed is about 50-60 for most DC motors to start moving
          duty = map(targetRPM, 1, MAX_RPM, 60, 255);
        }
        analogWrite(MOTOR_PIN, duty);
        Serial.print(">> Target set to ");
        Serial.print(targetRPM);
        Serial.println(" RPM");
      }
      else
      {
        Serial.println("! Invalid RPM (0–" + String(MAX_RPM) + ")");
      }
    }
    // if line was blank (just a newline), we do nothing and leave targetRPM unchanged
  }

  // — every INTERVAL_MS, compute and display actual RPM —
  unsigned long now = millis();
  if (now - lastMeasureTime >= INTERVAL_MS)
  {

    // snapshot & reset pulse count atomically
    noInterrupts();
    uint32_t pulses = pulseCount;
    pulseCount = 0;
    interrupts();

    // calculate RPM: (pulses / PULSES_PER_REV) * (60 000 ms / INTERVAL_MS)
    uint32_t actualRPM = ((uint32_t)pulses * 60UL * (1000UL / INTERVAL_MS) / PULSES_PER_REV) * RPM_CALIBRATION_FACTOR;

    // Adjust PWM duty cycle based on error between target and actual RPM
    if (targetRPM > 0)
    {
      // Set initial duty if coming from zero (motor was off)
      if (currentDuty < 60)
      {
        currentDuty = map(targetRPM, 1, MAX_RPM, 80, 255); // Increased minimum from 60 to 80
      }

      // Calculate PID terms
      int error = targetRPM - actualRPM;

      // P term - proportional to current error
      float pTerm = KP * error;

      // I term - accumulates over time, but with more aggressive accumulation for low RPM
      float integralFactor = 1.0;
      if (actualRPM < targetRPM * 0.8)
      {
        integralFactor = 1.5; // Accumulate integral faster when significantly below target
      }
      integral += error * (INTERVAL_MS / 1000.0) * integralFactor;

      // Anti-windup - limit the integral term
      integral = constrain(integral, -MAX_INTEGRAL, MAX_INTEGRAL);
      float iTerm = KI * integral;

      // D term - rate of change of error
      float derivative = (error - lastError) / (INTERVAL_MS / 1000.0);
      float dTerm = KD * derivative;
      lastError = error;

      // Combined PID adjustment
      int adjustment = pTerm + iTerm + dTerm;

      // Add boost factor when RPM is too low
      if (error > 0 && actualRPM < targetRPM * 0.9)
      {
        adjustment *= 2.0; // Stronger boost (changed from 1.5)
      }

      // Apply a minimum adjustment when below target
      if (error > 10 && adjustment < 5)
      {
        adjustment = 5; // Ensure we're making progress toward target
      }

      // Update duty cycle with constraints
      int newDuty = constrain(currentDuty + adjustment, 80, 255); // Increased minimum from 60 to 80

      // Always update the motor
      currentDuty = newDuty;
      analogWrite(MOTOR_PIN, currentDuty);

      // Debugging output remains the same
      Serial.print(" | P:");
      Serial.print(pTerm);
      Serial.print(" I:");
      Serial.print(iTerm);
      Serial.print(" D:");
      Serial.print(dTerm);
      Serial.print(" PWM:");
      Serial.print(currentDuty);
      Serial.print(" | Error:");
      Serial.print(error);
      Serial.print(" | Integral:");
      Serial.print(integral);
      Serial.print(" | ");
    }
    else
    {
      // If target RPM is 0, reset control variables
      currentDuty = 0;
      integral = 0;
      lastError = 0;
      analogWrite(MOTOR_PIN, 0);
    }

    // // Update PWM value in every loop iteration
    // if (targetRPM == 0)
    // {
    //   // Stop motor immediately if target is zero
    //   analogWrite(MOTOR_PIN, 0);
    //   currentDuty = 0;
    //   integral = 0;
    //   lastError = 0;
    // }
    // else
    // {
    //   // Simple proportional control - for more precise control, uncomment the PID section below
    //   // Map target RPM to PWM duty cycle (minimum 60 to overcome motor inertia)
    //   uint8_t duty = map(targetRPM, 1, MAX_RPM, 60, 255);
    //   analogWrite(MOTOR_PIN, duty);
    //   currentDuty = duty;
    //   Serial.print("Duty: ");
    //   Serial.print(duty);
    //   Serial.print("  |  ");
    // }
    

      // — update LCD —
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Tgt:");
      lcd.print(targetRPM);
      lcd.print("rpm");
      lcd.setCursor(0, 1);
      lcd.print("Act:");
      lcd.print(actualRPM);
      lcd.print("rpm");

      // — print to Serial —
      Serial.print("Target RPM: ");
      Serial.print(targetRPM);
      Serial.print("  |  Actual RPM: ");
      Serial.println(actualRPM);

      lastMeasureTime = now;
    }
  }
