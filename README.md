# ESP32-C3 cell classifier (OpenPLC)

The [esp32-cell-classifier](https://github.com/bennonegri/esp32-cell-classifier)
firmware rebuilt as an OpenPLC Editor v4 project. Same circuit, same test
sequence, same classification and LED states. The top-level program is
ladder logic, the measurement and classification maths are IEC 61131-3
Structured Text function blocks, and two small C/C++ blocks handle the
ESP32-C3 hardware that OpenPLC's generic I/O can't drive.

Target board: **ESP32-C3-DevKitM-1** (on-board WS2812 on GPIO 8, USB
through the on-board USB-UART bridge).

The tester waits for a cell, measures its open-circuit voltage (OCV) and
internal resistance (IR), classifies the chemistry and shows the state on
the on-board LED:

| LED                | State                                                  |
| ------------------ | ------------------------------------------------------ |
| green solid        | ready, insert a cell                                   |
| yellow solid       | cell detected: waiting for a stable OCV                |
| yellow flash 3 Hz  | load on, measuring IR                                  |
| result solid       | chemistry for 5 s, or red if no chemistry matched      |
| red flash 5 Hz     | fault, load off, until the cell is removed             |
| green flash 3 Hz   | remove the cell to test another                        |

Result colours: AA Alkaline orange, AA NiMH white, 14500 Li-ion blue,
14500 LiFePO4 purple.

## Project layout

| Firmware (`src/`, `include/`) | OpenPLC project                                   |
| ----------------------------- | ------------------------------------------------- |
| `main.cpp`                    | `pous/programs/main.ld`: tester state machine, ladder |
| `cell_test.cpp`               | `pous/function-blocks/CELL_TEST.st`               |
| `cell_classifier.cpp`         | `pous/function-blocks/CELL_CLASSIFIER.st`         |
| `status_led.cpp`              | `pous/function-blocks/STATUS_LED.st`              |
| `cell_adc.cpp`                | `pous/function-blocks/ESP32C3_INPUTS.cpp`         |
| `load_control.cpp`, LED write | `pous/function-blocks/ESP32C3_OUTPUTS.cpp`        |
| `millis()`                    | `pous/function-blocks/MS_CLOCK.st`                |
| `config.h`                    | `datatypes/TESTER_CONFIG.dt`, plus the hardware constants at the top of the two C/C++ blocks |

`nextSampleTime.st` keeps the sample cadence fixed. The other data types are
in `datatypes/`. `main` runs every 20 ms on `task0`.

Each scan runs like a PLC: `ESP32C3_INPUTS` reads the input image, the
logic runs, and `ESP32C3_OUTPUTS` writes the outputs. The firmware's
blocking waits became timers checked every scan.

### The ladder program

`main` has 27 rungs, each with a comment, in scan order:

1. **Inputs (rungs 1-4).** Read the clock and the ADC pins, scale the cell
   voltage through the divider and calibration factor, and set
   `cellPresent`.
2. **State machine (rungs 5-15).** Each state is one BOOL bit, switched by
   set/reset coils: `stReady` (on at boot), `stTesting`, `stResult`,
   `stRemove` and `stFault`. While `stTesting` is on, its contact powers
   `CELL_TEST`'s START. When the test is DONE, the rungs log the result
   and branch: removed → ready, `cellTest.FAULT` → fault, otherwise
   `CELL_CLASSIFIER` runs → result. A TON holds the result for
   `CFG.RESULT_DISPLAY_TIME`. Removing the cell from the remove or fault
   state returns to ready.
3. **LED (rungs 16-24).** MOVE blocks pick the colour and flash rate for
   the active state, then `STATUS_LED` runs.
4. **Outputs (rungs 25-27).** Pass the load setpoint only while testing,
   and write the output image.

## Hardware

The circuit is unchanged. See the comments in the C/C++ blocks for the RC
filter details.

| GPIO | Function                                                 |
| ---- | -------------------------------------------------------- |
| 1    | load setpoint, 20 kHz 10-bit PWM, RC-filtered to the op-amp |
| 2    | Vload (top of RL), ADC                                   |
| 3    | Vcell through the 27k / 39k divider, ADC                 |
| 8    | on-board WS2812 LED                                      |

### Why two blocks are C/C++

- The status LED is an addressable WS2812. Plain digital outputs can't
  drive it, so `ESP32C3_OUTPUTS` uses the core's `rgbLedWrite()`.
- OpenPLC's analogue inputs return raw, uncalibrated counts.
  `ESP32C3_INPUTS` averages 64 `analogReadMilliVolts()` readings, which
  applies the factory eFuse calibration. That keeps the DMM-checked
  `CELL_CAL_GAIN` valid.
- OpenPLC's analogue outputs run their PWM at 4 kHz. That would leave about
  5x the ripple on the load setpoint, so `ESP32C3_OUTPUTS` drives GPIO 1
  at 20 kHz.

The project needs OpenPLC Editor v4, and the C/C++ blocks need the
arduino-esp32 3.x core, which OpenPLC's ESP32 HAL also requires. On any other target the blocks compile to
nothing, so their variables can be forced from the debugger.

## Build and upload

1. Install [OpenPLC Editor](https://autonomylogic.com/) v4 with the
   Espressif (ESP32) board package.
2. Open this folder as a project.
3. In **Device**, select the `ESP32-C3` board and the DevKitM-1's serial
   port. The DevKitM-1 has no board entry of its own: it builds as the
   arduino-esp32 "ESP32C3 Dev Module" (`esp32:esp32:esp32c3`), which is
   what OpenPLC's ESP32-C3 entry uses. If the package names the board
   differently, pick its ESP32-C3 entry. The OpenPLC debugger talks over
   the same USB port the firmware's serial log used.
4. Keep the **pin mapping table empty** (it is empty in this project). The
   HAL configures every mapped pin at boot, which would clash with GPIO 1,
   2, 3 and 8. If you add I/O, use other pins.
5. Build and upload.

## Tuning

Everything in `config.h` that isn't a pin or PWM setting is in
`TESTER_CONFIG`. The program holds one instance, `main.CFG`, with the
firmware's defaults. Change a default in `datatypes/TESTER_CONFIG.dt` to
make it permanent, or write `main.CFG` from the debugger to try a value
live.

Pins, PWM frequency and resolution, the GPIO high level and the ADC sample
count are constants at the top of the two C/C++ blocks.

## Monitoring

OpenPLC uses the USB serial port for its debugger, so the firmware's serial
log is gone. Instead, `main` keeps the latest test in variables you can
watch in the debugger:

| Variable               | Meaning                                              |
| ---------------------- | ---------------------------------------------------- |
| `TEST_COUNT`           | tests run since boot                                 |
| `LAST_RESULT`          | chemistry, `Unknown`, `Removed` or `Fault`           |
| `LAST_STATUS`          | `TS_OK` or the fault: `TS_OCV_NOT_SETTLED`, `TS_ADC_OVER_RANGE`, `TS_CELL_SAG`, `TS_OVER_CURRENT` |
| `LAST_OCV_V`, `LAST_SETTLE_MS` | stable OCV and time to settle               |
| `LAST_LOADED_V`, `LAST_LOAD_V` | terminal and RL voltages under load         |
| `LAST_SET_CURRENT_MA`, `LAST_LOAD_CURRENT_MA` | requested and measured current |
| `LAST_IR_MOHM`, `LAST_SCORE` | internal resistance and match score            |

The live state is in the `st*` bits, `cellV`, `cellPresent`, `loadV` and
the `cellTest` and `classifier` instances. Contacts and coils on the
rungs highlight live in the debugger.

## Differences from the firmware

- **Timing follows the 20 ms scan.** Each sample is taken on the first scan
  at or after it is due, on a fixed cadence. The 200 ms OCV samples and
  1 s load step land exactly. The 50 ms load checks land 0-10 ms late
  but average 50 ms. Cell presence is checked every scan rather than every
  200 ms.
- **Load setpoint timing.** A new setpoint is written at the end of the
  scan and read back from a later scan, so the first check under load
  still sees a settled load (7 tau of the PWM filter is 33 ms).
- **Boot.** GPIO 1 is driven low on the first scan, slightly later after
  boot than the firmware's `setup()` did it.
- **No serial log.** See Monitoring above.

## Tests

`tests/` holds unit tests for every ST block and end-to-end tests that run
`main` against a simulated cell, divider and load (normal results, unknown
cell, faults, removal mid-test, exactly one state bit set). They use the
test runner built into [STruC++](https://github.com/Autonomy-Logic/STruCpp),
the compiler OpenPLC Editor v4 uses. On the host, `tests/host/` replaces
the two C/C++ blocks.

`main` is ladder, so its tests run on the Structured Text the editor
transpiles it to. Build the project in the editor first (any target);
`run_tests.sh` takes `PROGRAM main` from the newest `build/*/src/program.st`.
Without a build newer than `main.ld`, it skips `test_main.st`.

```sh
# Needs strucpp on PATH, or pass its path as the first argument.
tests/run_tests.sh
```

The project was also checked with OpenPLC Editor 4.3.2's own loader and
build pipeline: it loads with no warnings and builds cleanly for the
OpenPLC Runtime v4 target. The ESP32-C3 firmware hasn't been built or run
on hardware yet.
