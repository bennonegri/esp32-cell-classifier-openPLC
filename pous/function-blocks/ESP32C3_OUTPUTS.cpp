(* ESP32-C3 output image: the electronic load setpoint and the on-board
   WS2812 LED. Call last in the scan.

   The load setpoint is a 20 kHz, 10-bit PWM on GPIO_1, RC-filtered to a DC
   voltage on the op-amp (+) input. The op-amp drives the MOSFET so the same
   voltage appears across RL. OpenPLC's generic analogue outputs run their
   PWM at 4 kHz, which would leave ~5x the ripple on that voltage.
     GPIO_1  PWM -> 47k series, 100nF to GND -> op-amp (+) input.
             tau 4.7 ms, fc 33.9 Hz. At 20 kHz the ripple is ~4.5 mV p-p
             at 0.5 V out; a step settles to 0.1% in ~33 ms (7 tau).
   The LED on GPIO_8 is addressable, which plain digital outputs can't
   drive. Keep GPIO 1 and 8 out of the board's pin mapping.

   Needs the arduino-esp32 3.x core, which OpenPLC's ESP32 HAL also
   requires. Does nothing on other targets. *)

FUNCTION_BLOCK ESP32C3_OUTPUTS
VAR_INPUT
  LOAD_SET_V : REAL; // voltage to hold across RL, clamped to 0..GPIO high
  LED_R : USINT;
  LED_G : USINT;
  LED_B : USINT;
END_VAR

#if defined(ARDUINO_ARCH_ESP32)
static const uint8_t kEsp32c3LoadPwmPin = 1;
static const uint8_t kEsp32c3LedPin = 8;
static const uint32_t kEsp32c3PwmFreqHz = 20000;  // ~590x the RC corner
static const uint8_t kEsp32c3PwmBits = 10;  // 3.2 mV per step
static const uint32_t kEsp32c3MaxDuty = (1u << kEsp32c3PwmBits) - 1;
// PWM high level. Measure on the board; it sets the duty-to-volts scale.
static const float kEsp32c3GpioHighV = 3.3f;

static uint32_t esp32c3LastDuty = 0;
static uint32_t esp32c3LastRgb = 0;

static void esp32c3WriteLed(uint8_t r, uint8_t g, uint8_t b)
{
    rgbLedWrite(kEsp32c3LedPin, r, g, b);
    esp32c3LastRgb = ((uint32_t)r << 16) | ((uint32_t)g << 8) | b;
}
#endif

void setup()
{
#if defined(ARDUINO_ARCH_ESP32)
    // Hold the pin low until the PWM takes over so the load stays off.
    pinMode(kEsp32c3LoadPwmPin, OUTPUT);
    digitalWrite(kEsp32c3LoadPwmPin, LOW);
    ledcAttach(kEsp32c3LoadPwmPin, kEsp32c3PwmFreqHz, kEsp32c3PwmBits);
    ledcWrite(kEsp32c3LoadPwmPin, 0);
    esp32c3LastDuty = 0;
    esp32c3WriteLed(0, 0, 0);
#endif
}

void loop()
{
#if defined(ARDUINO_ARCH_ESP32)
    // Filtered PWM voltage = duty fraction * GPIO high level.
    const float volts = constrain((float)LOAD_SET_V, 0.0f, kEsp32c3GpioHighV);
    const uint32_t duty = lroundf(volts / kEsp32c3GpioHighV * kEsp32c3MaxDuty);
    if (duty != esp32c3LastDuty)
    {
        ledcWrite(kEsp32c3LoadPwmPin, duty);
        esp32c3LastDuty = duty;
    }

    // The WS2812 holds its colour, so only rewrite it on a change.
    const uint8_t r = LED_R;
    const uint8_t g = LED_G;
    const uint8_t b = LED_B;
    if ((((uint32_t)r << 16) | ((uint32_t)g << 8) | b) != esp32c3LastRgb)
    {
        esp32c3WriteLed(r, g, b);
    }
#endif
}

END_FUNCTION_BLOCK
