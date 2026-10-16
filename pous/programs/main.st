(* ESP32-C3 cell classifier.

   Waits for a cell, measures its open-circuit voltage and internal
   resistance, classifies the chemistry and shows the state on the LED:
     green  solid        ready, insert a cell
     yellow solid        cell detected: waiting for a stable OCV
     yellow flash 3 Hz   load on, measuring IR
     result solid        chemistry for RESULT_DISPLAY_MS (see
                         CELL_CLASSIFIER), or red if no chemistry matched
     red    flash 5 Hz   fault, load off, until the cell is removed: OCV
                         did not settle, ADC over range, cell sagged or
                         over-current
     green  flash 3 Hz   remove the cell to test another

   The firmware's serial log is replaced by the LAST_* variables below,
   which hold the latest test for the debugger. Tune the tester in CFG
   (TESTER_CONFIG). *)

PROGRAM main
VAR
  CFG : TESTER_CONFIG;
  state : TESTER_STATE := ST_READY;
  stateStartMs : UDINT;

  inputs : ESP32C3_INPUTS;
  outputs : ESP32C3_OUTPUTS;
  clock : MS_CLOCK;
  cellTest : CELL_TEST;
  classifier : CELL_CLASSIFIER;
  led : STATUS_LED;

  cellV : REAL; // cell terminal voltage
  loadV : REAL; // voltage across RL
  cellPresent : BOOL;
  ledColor : RGB;
  ledFlashHz : REAL;

  // Latest test, in place of the firmware's serial log
  TEST_COUNT : UDINT;
  LAST_RESULT : STRING; // chemistry, 'Unknown', 'Removed' or 'Fault'
  LAST_STATUS : TEST_STATUS;
  LAST_OCV_V : REAL; // stable OCV, or last reading on a fault
  LAST_SETTLE_MS : UDINT;
  LAST_SET_CURRENT_MA : REAL; // 0 if the load never ran
  LAST_LOAD_CURRENT_MA : REAL;
  LAST_LOADED_V : REAL;
  LAST_LOAD_V : REAL; // measured voltage across RL
  LAST_IR_MOHM : REAL;
  LAST_SCORE : REAL;
END_VAR
VAR CONSTANT
  GREEN : RGB := (R := 0, G := 255, B := 0); // ready (solid) / remove cell (flash)
  YELLOW : RGB := (R := 255, G := 200, B := 0); // settle + OCV (solid) / load (flash)
  RED : RGB := (R := 255, G := 0, B := 0); // unknown cell (solid) / fault (flash)
END_VAR

(* ---- Inputs ---- *)
clock();
inputs();

(* Cell voltage = ADC pin voltage * (R_TOP + R_BOTTOM) / R_BOTTOM, trimmed
   by the measured calibration factor. *)
cellV := inputs.CELL_PIN_V * CFG.CELL_CAL_GAIN
         * (CFG.DIVIDER_R_TOP_OHM + CFG.DIVIDER_R_BOTTOM_OHM)
         / CFG.DIVIDER_R_BOTTOM_OHM;
loadV := inputs.LOAD_PIN_V;
cellPresent := cellV > CFG.CELL_PRESENT_THRESHOLD_V;

(* ---- Tester state ---- *)
IF state = ST_READY AND cellPresent THEN
  state := ST_TESTING;
  stateStartMs := clock.NOW_MS;
END_IF;

cellTest(START := state = ST_TESTING,
     NOW_MS := clock.NOW_MS,
     CELL_V := cellV,
     LOAD_V := loadV,
     CELL_PIN_V := inputs.CELL_PIN_V,
     LOAD_PIN_V := inputs.LOAD_PIN_V,
     CFG := CFG);

CASE state OF
  ST_TESTING:
    IF cellTest.DONE THEN
      TEST_COUNT := TEST_COUNT + 1;
      LAST_STATUS := cellTest.STATUS;
      LAST_OCV_V := cellTest.OCV_V;
      LAST_SETTLE_MS := cellTest.SETTLE_MS;
      LAST_SET_CURRENT_MA := cellTest.SET_CURRENT_A * 1000.0;
      LAST_LOAD_CURRENT_MA := cellTest.LOAD_CURRENT_A * 1000.0;
      LAST_LOADED_V := cellTest.LOADED_V;
      LAST_LOAD_V := cellTest.LOAD_V_MEAS;
      LAST_IR_MOHM := 0.0;
      LAST_SCORE := 0.0;
      stateStartMs := clock.NOW_MS;

      IF cellTest.STATUS = TS_CELL_REMOVED OR NOT cellPresent THEN
        LAST_RESULT := 'Removed';
        state := ST_READY;
      ELSIF cellTest.STATUS <> TS_OK THEN
        (* Load is already off; flash red until the cell is removed. *)
        LAST_RESULT := 'Fault';
        state := ST_FAULT;
      ELSE
        classifier(OCV_V := cellTest.OCV_V,
                   IR_OHM := cellTest.IR_OHM,
                   IR_VALID := cellTest.IR_VALID,
                   CFG := CFG);
        IF cellTest.IR_VALID THEN
          LAST_IR_MOHM := cellTest.IR_OHM * 1000.0;
        END_IF;
        LAST_RESULT := classifier.NAME;
        LAST_SCORE := classifier.SCORE;
        state := ST_RESULT;
      END_IF;
    END_IF;

  ST_RESULT:
    (* Then wait for removal so the same cell isn't tested again. *)
    IF clock.NOW_MS - stateStartMs >= CFG.RESULT_DISPLAY_MS THEN
      state := ST_REMOVE;
      stateStartMs := clock.NOW_MS;
    END_IF;

  ST_REMOVE, ST_FAULT:
    IF NOT cellPresent THEN
      state := ST_READY;
      stateStartMs := clock.NOW_MS;
    END_IF;
END_CASE;

(* ---- LED ---- *)
ledFlashHz := 0.0;
CASE state OF
  ST_READY:
    ledColor := GREEN;
  ST_TESTING:
    ledColor := YELLOW;
    IF cellTest.LOADING THEN
      ledFlashHz := CFG.STATUS_FLASH_HZ;
    END_IF;
  ST_RESULT:
    IF classifier.MATCHED THEN
      ledColor := classifier.COLOR;
    ELSE
      ledColor := RED;
    END_IF;
  ST_REMOVE:
    ledColor := GREEN;
    ledFlashHz := CFG.STATUS_FLASH_HZ;
  ST_FAULT:
    ledColor := RED;
    ledFlashHz := CFG.FAULT_FLASH_HZ;
END_CASE;

led(NOW_MS := clock.NOW_MS,
    COLOR := ledColor,
    FLASH_HZ := ledFlashHz,
    BRIGHTNESS := CFG.LED_BRIGHTNESS);

(* ---- Outputs ---- *)
(* The load only runs inside a test; CELL_TEST turns it off on a fault. *)
IF state = ST_TESTING THEN
  outputs.LOAD_SET_V := cellTest.LOAD_SET_V;
ELSE
  outputs.LOAD_SET_V := 0.0;
END_IF;
outputs(LED_R := led.R, LED_G := led.G, LED_B := led.B);

END_PROGRAM
