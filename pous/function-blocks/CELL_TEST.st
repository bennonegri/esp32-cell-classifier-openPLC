(* Cell measurement sequence: wait for a stable open-circuit voltage, then
   apply a load step to back-calculate internal resistance (IR).

   Runs while START is TRUE; a rising edge starts a new test. It stops at
   the first fault with DONE set, BUSY cleared and the load off, and holds
   the results until the next start. START going FALSE aborts the test and
   turns the load off.

   1. Sample the unloaded cell every OCV_SAMPLE_INTERVAL_MS. Once two
      consecutive windows of OCV_STABLE_WINDOW samples agree within
      OCV_STABLE_RATE_V_PER_S, the newest window mean is the OCV. Not
      stable within OCV_SETTLE_TIMEOUT_MS is a fault.
   2. Apply the load at a current chosen by chemistry group. Check it every
      LOAD_CHECK_INTERVAL_MS, with the final reading at LOAD_TIME_MS.
   3. IR = (OCV - V_loaded) / I, only if the load step completed.

   Samples are taken on the first scan at or after each interval, on a
   fixed cadence so the scan time doesn't stretch the intervals.

   The load setpoint reaches the hardware at the end of the scan and the
   readings come from the start of a later scan, so every check under load
   sees a settled load, as in the firmware. *)

FUNCTION_BLOCK CELL_TEST
VAR_INPUT
  START : BOOL;
  NOW_MS : UDINT;
  CELL_V : REAL; // cell terminal voltage
  LOAD_V : REAL; // voltage across RL
  CELL_PIN_V : REAL; // ADC pin voltages, for the over-range check
  LOAD_PIN_V : REAL;
  CFG : TESTER_CONFIG;
END_VAR
VAR_OUTPUT
  BUSY : BOOL;
  DONE : BOOL; // finished; STATUS and results are valid
  LOADING : BOOL; // load step in progress
  LOAD_SET_V : REAL; // voltage to hold across RL, 0 = load off
  STATUS : TEST_STATUS;
  OCV_V : REAL; // stable OCV, or last reading on a fault
  SETTLE_MS : UDINT; // time spent waiting for a stable OCV
  SET_CURRENT_A : REAL; // requested load current, 0 if the load never ran
  LOADED_V : REAL; // terminal voltage at the end of the load
  LOAD_V_MEAS : REAL; // measured voltage across RL
  LOAD_CURRENT_A : REAL; // LOAD_V_MEAS / LOAD_RESISTOR_OHM
  IR_OHM : REAL; // valid only if IR_VALID
  IR_VALID : BOOL;
END_VAR
VAR CONSTANT
  MAX_WINDOW : INT := 10;
END_VAR
VAR
  running : BOOL;
  history : ARRAY[0..19] OF REAL; // oldest first
  count : INT;
  windowLen : INT;
  i : INT;
  older : REAL;
  newer : REAL;
  windowSpanS : REAL;
  startMs : UDINT;
  lastSampleMs : UDINT;
  loadStartMs : UDINT;
  firstSample : BOOL;
END_VAR

IF NOT START THEN
  running := FALSE;
  BUSY := FALSE;
  DONE := FALSE;
  LOADING := FALSE;
  LOAD_SET_V := 0.0;
ELSE
  IF NOT running AND NOT DONE THEN
    (* Rising edge of START: begin with the load off. *)
    running := TRUE;
    BUSY := TRUE;
    LOADING := FALSE;
    LOAD_SET_V := 0.0;
    STATUS := TS_OK;
    OCV_V := 0.0;
    SETTLE_MS := 0;
    SET_CURRENT_A := 0.0;
    LOADED_V := 0.0;
    LOAD_V_MEAS := 0.0;
    LOAD_CURRENT_A := 0.0;
    IR_OHM := 0.0;
    IR_VALID := FALSE;
    count := 0;
    windowLen := LIMIT(1, USINT_TO_INT(CFG.OCV_STABLE_WINDOW), MAX_WINDOW);
    windowSpanS := INT_TO_REAL(windowLen) * UDINT_TO_REAL(CFG.OCV_SAMPLE_INTERVAL_MS) / 1000.0;
    startMs := NOW_MS;
    firstSample := TRUE;
  END_IF;

  (* ---- 1. Wait for a stable OCV ---- *)
  IF running AND NOT LOADING
      AND (firstSample OR NOW_MS - lastSampleMs >= CFG.OCV_SAMPLE_INTERVAL_MS) THEN
    IF firstSample THEN
      firstSample := FALSE;
      lastSampleMs := NOW_MS;
    ELSE
      lastSampleMs := nextSampleTime(lastSampleMs, NOW_MS, CFG.OCV_SAMPLE_INTERVAL_MS);
    END_IF;

    (* Latest reading until both windows are full, then the newest mean. *)
    OCV_V := CELL_V;
    SETTLE_MS := NOW_MS - startMs;
    IF CELL_PIN_V > CFG.ADC_MAX_PIN_V THEN
      STATUS := TS_ADC_OVER_RANGE;
    ELSIF CELL_V <= CFG.CELL_PRESENT_THRESHOLD_V THEN
      STATUS := TS_CELL_REMOVED;
    ELSE
      (* Append, dropping the oldest sample once the history is full. *)
      IF count = 2 * windowLen THEN
        FOR i := 1 TO count - 1 DO
          history[i - 1] := history[i];
        END_FOR;
        count := count - 1;
      END_IF;
      history[count] := CELL_V;
      count := count + 1;

      IF count = 2 * windowLen THEN
        older := 0.0;
        newer := 0.0;
        FOR i := 0 TO windowLen - 1 DO
          older := older + history[i];
          newer := newer + history[i + windowLen];
        END_FOR;
        older := older / INT_TO_REAL(windowLen);
        newer := newer / INT_TO_REAL(windowLen);
        OCV_V := newer;

        IF ABS(newer - older) / windowSpanS <= CFG.OCV_STABLE_RATE_V_PER_S THEN
          (* ---- 2. Load step, current chosen by chemistry group ---- *)
          IF OCV_V > CFG.LITHIUM_OCV_THRESHOLD_V THEN
            SET_CURRENT_A := CFG.LITHIUM_LOAD_CURRENT_A;
          ELSE
            SET_CURRENT_A := CFG.AA_LOAD_CURRENT_A;
          END_IF;
          LOAD_SET_V := SET_CURRENT_A * CFG.LOAD_RESISTOR_OHM;
          LOADING := TRUE;
          loadStartMs := NOW_MS;
          lastSampleMs := NOW_MS;
        END_IF;
      END_IF;

      IF NOT LOADING AND SETTLE_MS >= CFG.OCV_SETTLE_TIMEOUT_MS THEN
        STATUS := TS_OCV_NOT_SETTLED;
      END_IF;
    END_IF;

  ELSIF running AND LOADING
      AND NOW_MS - lastSampleMs >= CFG.LOAD_CHECK_INTERVAL_MS THEN
    lastSampleMs := nextSampleTime(lastSampleMs, NOW_MS, CFG.LOAD_CHECK_INTERVAL_MS);

    (* Read the loaded cell and RL voltages and check them against the
       limits. *)
    LOAD_V_MEAS := LOAD_V;
    LOADED_V := CELL_V;
    LOAD_CURRENT_A := LOAD_V / CFG.LOAD_RESISTOR_OHM;
    IF CELL_PIN_V > CFG.ADC_MAX_PIN_V OR LOAD_PIN_V > CFG.ADC_MAX_PIN_V THEN
      STATUS := TS_ADC_OVER_RANGE;
    ELSIF LOAD_CURRENT_A > SET_CURRENT_A * CFG.OVER_CURRENT_RATIO THEN
      STATUS := TS_OVER_CURRENT;
    ELSIF LOADED_V < LOAD_SET_V + CFG.MIN_LOAD_HEADROOM_V THEN
      (* Below this the MOSFET can't hold the set current, so IR is
         invalid. *)
      STATUS := TS_CELL_SAG;
    ELSIF NOW_MS - loadStartMs >= CFG.LOAD_TIME_MS THEN
      (* ---- 3. IR = (OCV - V_loaded) / I ---- *)
      IF LOAD_CURRENT_A > 0.0 THEN
        IR_OHM := (OCV_V - LOADED_V) / LOAD_CURRENT_A - CFG.FIXTURE_RESISTANCE_OHM;
        IR_VALID := TRUE;
      END_IF;
      running := FALSE;
    END_IF;
  END_IF;

  (* Finished, by fault or by completing the load step. *)
  IF running AND STATUS <> TS_OK THEN
    running := FALSE;
  END_IF;
  IF NOT running AND BUSY THEN
    BUSY := FALSE;
    DONE := TRUE;
    LOADING := FALSE;
    LOAD_SET_V := 0.0;
  END_IF;
END_IF;

END_FUNCTION_BLOCK
