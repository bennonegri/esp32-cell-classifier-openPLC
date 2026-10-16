(* Each loop iteration is one 20 ms scan. The simulated load sees the
   setpoint from the previous scan, as the hardware does. *)

SETUP
VAR
  cfg : TESTER_CONFIG;
  sim : CELL_SIM;
  t : CELL_TEST;
  now : UDINT;
END_VAR
  now := 0;
END_SETUP

TEST 'Stable AA cell: OCV, then IR at the AA current'
VAR
  k : INT;
END_VAR
  FOR k := 1 TO 200 DO
    sim(PRESENT := TRUE, OCV_V := 1.5, IR_OHM := 0.15,
        LOAD_SET_V := t.LOAD_SET_V, CFG := cfg);
    t(START := TRUE, NOW_MS := now, CELL_V := sim.CELL_V,
      LOAD_V := sim.LOAD_PIN_V, CELL_PIN_V := sim.CELL_PIN_V,
      LOAD_PIN_V := sim.LOAD_PIN_V, CFG := cfg);
    IF t.DONE THEN EXIT; END_IF;
    ASSERT_TRUE(t.BUSY);
    now := now + 20;
  END_FOR;
  ASSERT_TRUE(t.DONE);
  ASSERT_FALSE(t.BUSY);
  ASSERT_TRUE(t.STATUS = TS_OK);
  ASSERT_FALSE(t.FAULT);
  (* 10 samples at 200 ms intervals, then a 1 s load step. *)
  ASSERT_EQ(t.SETTLE_MS, 1800);
  ASSERT_EQ(now, 2800);
  ASSERT_NEAR(t.OCV_V, 1.5, 0.0001);
  ASSERT_NEAR(t.SET_CURRENT_A, 0.05, 0.0001);
  ASSERT_NEAR(t.LOAD_CURRENT_A, 0.05, 0.0001);
  ASSERT_NEAR(t.LOADED_V, 1.4925, 0.0001);
  ASSERT_TRUE(t.IR_VALID);
  ASSERT_NEAR(t.IR_OHM, 0.15, 0.001);
  ASSERT_EQ(t.LOAD_SET_V, 0.0);
  ASSERT_FALSE(t.LOADING);
END_TEST

TEST 'Load is on only during the load step'
VAR
  k : INT;
END_VAR
  FOR k := 1 TO 200 DO
    sim(PRESENT := TRUE, OCV_V := 1.5, IR_OHM := 0.15,
        LOAD_SET_V := t.LOAD_SET_V, CFG := cfg);
    t(START := TRUE, NOW_MS := now, CELL_V := sim.CELL_V,
      LOAD_V := sim.LOAD_PIN_V, CELL_PIN_V := sim.CELL_PIN_V,
      LOAD_PIN_V := sim.LOAD_PIN_V, CFG := cfg);
    IF now < 1800 THEN
      ASSERT_FALSE(t.LOADING);
      ASSERT_EQ(t.LOAD_SET_V, 0.0);
    ELSIF now < 2800 THEN
      ASSERT_TRUE(t.LOADING);
      ASSERT_NEAR(t.LOAD_SET_V, 0.25, 0.0001);
    END_IF;
    IF t.DONE THEN EXIT; END_IF;
    now := now + 20;
  END_FOR;
  ASSERT_TRUE(t.DONE);
END_TEST

TEST 'Lithium OCV uses the lithium current'
VAR
  k : INT;
END_VAR
  FOR k := 1 TO 200 DO
    sim(PRESENT := TRUE, OCV_V := 3.7, IR_OHM := 0.1,
        LOAD_SET_V := t.LOAD_SET_V, CFG := cfg);
    t(START := TRUE, NOW_MS := now, CELL_V := sim.CELL_V,
      LOAD_V := sim.LOAD_PIN_V, CELL_PIN_V := sim.CELL_PIN_V,
      LOAD_PIN_V := sim.LOAD_PIN_V, CFG := cfg);
    IF t.DONE THEN EXIT; END_IF;
    now := now + 20;
  END_FOR;
  ASSERT_TRUE(t.STATUS = TS_OK);
  ASSERT_NEAR(t.SET_CURRENT_A, 0.1, 0.0001);
  ASSERT_NEAR(t.IR_OHM, 0.1, 0.001);
END_TEST

TEST 'OCV drifting faster than 2 mV/s times out'
VAR
  k : INT;
END_VAR
  FOR k := 1 TO 1000 DO
    sim(PRESENT := TRUE, OCV_V := 1.4 + UDINT_TO_REAL(now) * 0.000005,
        IR_OHM := 0.15, LOAD_SET_V := t.LOAD_SET_V, CFG := cfg);
    t(START := TRUE, NOW_MS := now, CELL_V := sim.CELL_V,
      LOAD_V := sim.LOAD_PIN_V, CELL_PIN_V := sim.CELL_PIN_V,
      LOAD_PIN_V := sim.LOAD_PIN_V, CFG := cfg);
    IF t.DONE THEN EXIT; END_IF;
    now := now + 20;
  END_FOR;
  ASSERT_TRUE(t.STATUS = TS_OCV_NOT_SETTLED);
  ASSERT_EQ(t.SETTLE_MS, 10000);
  ASSERT_EQ(t.SET_CURRENT_A, 0.0);
  ASSERT_FALSE(t.IR_VALID);
END_TEST

TEST 'OCV drifting slower than 2 mV/s settles'
VAR
  k : INT;
END_VAR
  FOR k := 1 TO 1000 DO
    sim(PRESENT := TRUE, OCV_V := 1.4 + UDINT_TO_REAL(now) * 0.0000015,
        IR_OHM := 0.15, LOAD_SET_V := t.LOAD_SET_V, CFG := cfg);
    t(START := TRUE, NOW_MS := now, CELL_V := sim.CELL_V,
      LOAD_V := sim.LOAD_PIN_V, CELL_PIN_V := sim.CELL_PIN_V,
      LOAD_PIN_V := sim.LOAD_PIN_V, CFG := cfg);
    IF t.LOADING THEN EXIT; END_IF;
    now := now + 20;
  END_FOR;
  ASSERT_TRUE(t.LOADING);
  ASSERT_EQ(t.SETTLE_MS, 1800);
END_TEST

TEST 'Removal while settling ends the test'
VAR
  k : INT;
END_VAR
  FOR k := 1 TO 200 DO
    sim(PRESENT := now < 600, OCV_V := 1.5, IR_OHM := 0.15,
        LOAD_SET_V := t.LOAD_SET_V, CFG := cfg);
    t(START := TRUE, NOW_MS := now, CELL_V := sim.CELL_V,
      LOAD_V := sim.LOAD_PIN_V, CELL_PIN_V := sim.CELL_PIN_V,
      LOAD_PIN_V := sim.LOAD_PIN_V, CFG := cfg);
    IF t.DONE THEN EXIT; END_IF;
    now := now + 20;
  END_FOR;
  ASSERT_TRUE(t.STATUS = TS_CELL_REMOVED);
  ASSERT_FALSE(t.FAULT);
  ASSERT_EQ(now, 600);
END_TEST

TEST 'ADC pin above its calibrated range is a fault'
  (* 4.5 V puts 2.67 V on the divider tap. *)
  sim(PRESENT := TRUE, OCV_V := 4.5, IR_OHM := 0.1,
      LOAD_SET_V := 0.0, CFG := cfg);
  t(START := TRUE, NOW_MS := now, CELL_V := sim.CELL_V,
    LOAD_V := sim.LOAD_PIN_V, CELL_PIN_V := sim.CELL_PIN_V,
    LOAD_PIN_V := sim.LOAD_PIN_V, CFG := cfg);
  ASSERT_TRUE(t.DONE);
  ASSERT_TRUE(t.STATUS = TS_ADC_OVER_RANGE);
END_TEST

TEST 'Cell sagging below the load headroom is a fault'
VAR
  k : INT;
END_VAR
  (* 1.3 V - 50 mA x 20 ohm = 0.3 V, under 0.25 V + 0.2 V headroom. *)
  FOR k := 1 TO 200 DO
    sim(PRESENT := TRUE, OCV_V := 1.3, IR_OHM := 20.0,
        LOAD_SET_V := t.LOAD_SET_V, CFG := cfg);
    t(START := TRUE, NOW_MS := now, CELL_V := sim.CELL_V,
      LOAD_V := sim.LOAD_PIN_V, CELL_PIN_V := sim.CELL_PIN_V,
      LOAD_PIN_V := sim.LOAD_PIN_V, CFG := cfg);
    IF t.DONE THEN EXIT; END_IF;
    now := now + 20;
  END_FOR;
  ASSERT_TRUE(t.STATUS = TS_CELL_SAG);
  ASSERT_EQ(now, 1860); (* first 50 ms check, on a 20 ms scan *)
  ASSERT_FALSE(t.IR_VALID);
  ASSERT_EQ(t.LOAD_SET_V, 0.0);
END_TEST

TEST 'Current above 1.4x the set current is a fault'
VAR
  k : INT;
END_VAR
  FOR k := 1 TO 200 DO
    sim(PRESENT := TRUE, OCV_V := 1.5, IR_OHM := 0.15,
        LOAD_SET_V := t.LOAD_SET_V, EXTRA_CURRENT_A := 0.05, CFG := cfg);
    t(START := TRUE, NOW_MS := now, CELL_V := sim.CELL_V,
      LOAD_V := sim.LOAD_PIN_V, CELL_PIN_V := sim.CELL_PIN_V,
      LOAD_PIN_V := sim.LOAD_PIN_V, CFG := cfg);
    IF t.DONE THEN EXIT; END_IF;
    now := now + 20;
  END_FOR;
  ASSERT_TRUE(t.STATUS = TS_OVER_CURRENT);
  ASSERT_TRUE(t.FAULT);
  ASSERT_NEAR(t.LOAD_CURRENT_A, 0.1, 0.0001);
  ASSERT_EQ(t.LOAD_SET_V, 0.0);
END_TEST

TEST 'Dropping START aborts and turns the load off'
VAR
  k : INT;
END_VAR
  FOR k := 1 TO 100 DO
    sim(PRESENT := TRUE, OCV_V := 1.5, IR_OHM := 0.15,
        LOAD_SET_V := t.LOAD_SET_V, CFG := cfg);
    t(START := TRUE, NOW_MS := now, CELL_V := sim.CELL_V,
      LOAD_V := sim.LOAD_PIN_V, CELL_PIN_V := sim.CELL_PIN_V,
      LOAD_PIN_V := sim.LOAD_PIN_V, CFG := cfg);
    now := now + 20;
  END_FOR;
  ASSERT_TRUE(t.LOADING);
  t(START := FALSE, NOW_MS := now, CFG := cfg);
  ASSERT_FALSE(t.BUSY);
  ASSERT_FALSE(t.DONE);
  ASSERT_FALSE(t.LOADING);
  ASSERT_EQ(t.LOAD_SET_V, 0.0);
END_TEST

TEST 'A new rising edge restarts with cleared results'
VAR
  k : INT;
END_VAR
  FOR k := 1 TO 200 DO
    sim(PRESENT := TRUE, OCV_V := 1.5, IR_OHM := 0.15,
        LOAD_SET_V := t.LOAD_SET_V, CFG := cfg);
    t(START := TRUE, NOW_MS := now, CELL_V := sim.CELL_V,
      LOAD_V := sim.LOAD_PIN_V, CELL_PIN_V := sim.CELL_PIN_V,
      LOAD_PIN_V := sim.LOAD_PIN_V, CFG := cfg);
    IF t.DONE THEN EXIT; END_IF;
    now := now + 20;
  END_FOR;
  ASSERT_TRUE(t.IR_VALID);
  (* Holding START does not start another test. *)
  t(START := TRUE, NOW_MS := now + 20, CELL_V := sim.CELL_V,
    LOAD_V := sim.LOAD_PIN_V, CELL_PIN_V := sim.CELL_PIN_V,
    LOAD_PIN_V := sim.LOAD_PIN_V, CFG := cfg);
  ASSERT_TRUE(t.DONE);
  t(START := FALSE, NOW_MS := now + 40, CFG := cfg);
  t(START := TRUE, NOW_MS := now + 60, CELL_V := sim.CELL_V,
    LOAD_V := sim.LOAD_PIN_V, CELL_PIN_V := sim.CELL_PIN_V,
    LOAD_PIN_V := sim.LOAD_PIN_V, CFG := cfg);
  ASSERT_TRUE(t.BUSY);
  ASSERT_FALSE(t.DONE);
  ASSERT_FALSE(t.IR_VALID);
  ASSERT_EQ(t.SETTLE_MS, 0);
END_TEST
