(* ESP32-C3 input image: the two analogue pins in volts, each the mean of
   ADC_SAMPLES readings with the factory eFuse calibration applied
   (analogReadMilliVolts). OpenPLC's generic analogue inputs are raw and
   uncalibrated, so the cell voltage would lose its DMM-checked accuracy.
   Call first in the scan.

   Pins and RC filters:
     GPIO_2  Vload (top of RL) -> 4.7k series, 100nF to GND -> ADC.
             tau 0.47 ms, fc 339 Hz.
     GPIO_3  Vcell -> 27k / 39k divider, 100nF from ADC pin to GND.
             Filter R is the divider's Thevenin resistance, 16k:
             tau 1.6 ms, fc 99.8 Hz.
   Keep GPIO 2 and 3 out of the board's pin mapping.

   On a target other than an ESP32 the outputs are left alone, so they can
   be forced from the debugger. *)

FUNCTION_BLOCK ESP32C3_INPUTS
VAR_OUTPUT
  CELL_PIN_V : REAL; // GPIO_3, divider output
  LOAD_PIN_V : REAL; // GPIO_2, voltage across RL
END_VAR

#if defined(ARDUINO_ARCH_ESP32)
static const uint8_t kEsp32c3LoadAdcPin = 2;  // ADC1 channel 2
static const uint8_t kEsp32c3CellAdcPin = 3;  // ADC1 channel 3
static const uint16_t kEsp32c3AdcSamples = 64;  // averaged per reading

// Mean pin voltage in volts.
static float esp32c3AverageVolts(uint8_t pin)
{
    uint32_t sumMilliVolts = 0;
    for (uint16_t i = 0; i < kEsp32c3AdcSamples; i++)
    {
        sumMilliVolts += analogReadMilliVolts(pin);
    }
    return sumMilliVolts / (kEsp32c3AdcSamples * 1000.0f);
}
#endif

void setup()
{
#if defined(ARDUINO_ARCH_ESP32)
    // 11 dB attenuation gives the widest input range (~0-2.5 V calibrated).
    // Vload is normally 0.25-0.5 V, but the wide range lets a fault current
    // still be measured.
    analogReadResolution(12);
    analogSetPinAttenuation(kEsp32c3CellAdcPin, ADC_11db);
    analogSetPinAttenuation(kEsp32c3LoadAdcPin, ADC_11db);
#endif
}

void loop()
{
#if defined(ARDUINO_ARCH_ESP32)
    CELL_PIN_V = esp32c3AverageVolts(kEsp32c3CellAdcPin);
    LOAD_PIN_V = esp32c3AverageVolts(kEsp32c3LoadAdcPin);
#endif
}

END_FUNCTION_BLOCK
