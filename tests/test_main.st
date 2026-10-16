(* The whole tester against a simulated cell. Each loop iteration is one
   20 ms scan: the simulated hardware reads the previous scan's outputs and
   feeds the input image, then the program runs. The program's clock is
   mocked and stepped by hand. *)

SETUP
VAR
  uut : main;
  sim : CELL_SIM;
  present : BOOL;
  ocv : REAL;
  ir : REAL;
  extraA : REAL;
  now : UDINT;
END_VAR
  present := FALSE;
  ocv := 1.5;
  ir := 0.15;
  extraA := 0.0;
  now := 0;
END_SETUP

TEST 'Ready with no cell: green, load off'
VAR
  k : INT;
END_VAR
  MOCK uut.clock;
  FOR k := 1 TO 10 DO
    sim(PRESENT := present, OCV_V := ocv, IR_OHM := ir,
        LOAD_SET_V := uut.outputs.LOAD_SET_V, EXTRA_CURRENT_A := extraA,
        CFG := uut.CFG);
    uut.inputs.CELL_PIN_V := sim.CELL_PIN_V;
    uut.inputs.LOAD_PIN_V := sim.LOAD_PIN_V;
    uut.clock.NOW_MS := now;
    uut();
    now := now + 20;
  END_FOR;
  ASSERT_TRUE(uut.state = ST_READY);
  ASSERT_EQ(uut.outputs.LED_R, 0);
  ASSERT_EQ(uut.outputs.LED_G, 64);
  ASSERT_EQ(uut.outputs.LED_B, 0);
  ASSERT_EQ(uut.outputs.LOAD_SET_V, 0.0);
  ASSERT_EQ(uut.TEST_COUNT, 0);
END_TEST

TEST 'AA alkaline: settle, load, result, remove, ready'
VAR
  k : INT;
  sawYellow : BOOL;
  sawLoad : BOOL;
END_VAR
  MOCK uut.clock;
  present := TRUE;
  FOR k := 1 TO 400 DO
    sim(PRESENT := present, OCV_V := ocv, IR_OHM := ir,
        LOAD_SET_V := uut.outputs.LOAD_SET_V, EXTRA_CURRENT_A := extraA,
        CFG := uut.CFG);
    uut.inputs.CELL_PIN_V := sim.CELL_PIN_V;
    uut.inputs.LOAD_PIN_V := sim.LOAD_PIN_V;
    uut.clock.NOW_MS := now;
    uut();
    now := now + 20;
    IF uut.state = ST_TESTING AND NOT uut.cellTest.LOADING THEN
      (* Yellow solid while settling. *)
      ASSERT_EQ(uut.outputs.LED_R, 64);
      ASSERT_EQ(uut.outputs.LED_G, 50);
      sawYellow := TRUE;
    END_IF;
    IF uut.outputs.LOAD_SET_V > 0.0 THEN
      sawLoad := TRUE;
    END_IF;
    IF uut.state = ST_RESULT THEN EXIT; END_IF;
  END_FOR;
  ASSERT_TRUE(sawYellow);
  ASSERT_TRUE(sawLoad);
  ASSERT_TRUE(uut.state = ST_RESULT);
  ASSERT_EQ(uut.TEST_COUNT, 1);
  ASSERT_EQ(uut.LAST_RESULT, 'AA Alkaline');
  ASSERT_TRUE(uut.LAST_STATUS = TS_OK);
  ASSERT_NEAR(uut.LAST_OCV_V, 1.5, 0.001);
  ASSERT_NEAR(uut.LAST_IR_MOHM, 150.0, 1.0);
  ASSERT_NEAR(uut.LAST_SET_CURRENT_MA, 50.0, 0.01);
  ASSERT_EQ(uut.outputs.LOAD_SET_V, 0.0);

  (* Orange result colour, held solid for 5 s. *)
  FOR k := 1 TO 240 DO
    sim(PRESENT := present, OCV_V := ocv, IR_OHM := ir,
        LOAD_SET_V := uut.outputs.LOAD_SET_V, EXTRA_CURRENT_A := extraA,
        CFG := uut.CFG);
    uut.inputs.CELL_PIN_V := sim.CELL_PIN_V;
    uut.inputs.LOAD_PIN_V := sim.LOAD_PIN_V;
    uut.clock.NOW_MS := now;
    uut();
    now := now + 20;
    ASSERT_TRUE(uut.state = ST_RESULT);
    ASSERT_EQ(uut.outputs.LED_R, 64);
    ASSERT_EQ(uut.outputs.LED_G, 20);
    ASSERT_EQ(uut.outputs.LED_B, 0);
  END_FOR;
  FOR k := 1 TO 20 DO
    sim(PRESENT := present, OCV_V := ocv, IR_OHM := ir,
        LOAD_SET_V := uut.outputs.LOAD_SET_V, EXTRA_CURRENT_A := extraA,
        CFG := uut.CFG);
    uut.inputs.CELL_PIN_V := sim.CELL_PIN_V;
    uut.inputs.LOAD_PIN_V := sim.LOAD_PIN_V;
    uut.clock.NOW_MS := now;
    uut();
    now := now + 20;
  END_FOR;

  (* Then flash green until the cell is removed; no second test. *)
  ASSERT_TRUE(uut.state = ST_REMOVE);
  ASSERT_EQ(uut.ledColor.G, 255);
  ASSERT_EQ(uut.ledFlashHz, 3.0);
  present := FALSE;
  FOR k := 1 TO 2 DO
    sim(PRESENT := present, OCV_V := ocv, IR_OHM := ir,
        LOAD_SET_V := uut.outputs.LOAD_SET_V, EXTRA_CURRENT_A := extraA,
        CFG := uut.CFG);
    uut.inputs.CELL_PIN_V := sim.CELL_PIN_V;
    uut.inputs.LOAD_PIN_V := sim.LOAD_PIN_V;
    uut.clock.NOW_MS := now;
    uut();
    now := now + 20;
  END_FOR;
  ASSERT_TRUE(uut.state = ST_READY);
  ASSERT_EQ(uut.TEST_COUNT, 1);
END_TEST

TEST 'Unknown cell shows solid red'
VAR
  k : INT;
END_VAR
  MOCK uut.clock;
  present := TRUE;
  ocv := 2.4;
  ir := 0.1;
  FOR k := 1 TO 400 DO
    sim(PRESENT := present, OCV_V := ocv, IR_OHM := ir,
        LOAD_SET_V := uut.outputs.LOAD_SET_V, EXTRA_CURRENT_A := extraA,
        CFG := uut.CFG);
    uut.inputs.CELL_PIN_V := sim.CELL_PIN_V;
    uut.inputs.LOAD_PIN_V := sim.LOAD_PIN_V;
    uut.clock.NOW_MS := now;
    uut();
    now := now + 20;
    IF uut.state = ST_RESULT THEN EXIT; END_IF;
  END_FOR;
  ASSERT_TRUE(uut.state = ST_RESULT);
  ASSERT_EQ(uut.LAST_RESULT, 'Unknown');
  ASSERT_GT(uut.LAST_SCORE, uut.CFG.MAX_MATCH_SCORE);
  ASSERT_EQ(uut.outputs.LED_R, 64);
  ASSERT_EQ(uut.outputs.LED_G, 0);
END_TEST

TEST 'Fault: load off, red flash until the cell is removed'
VAR
  k : INT;
  litScans : INT;
  darkScans : INT;
END_VAR
  MOCK uut.clock;
  present := TRUE;
  extraA := 0.05;
  FOR k := 1 TO 400 DO
    sim(PRESENT := present, OCV_V := ocv, IR_OHM := ir,
        LOAD_SET_V := uut.outputs.LOAD_SET_V, EXTRA_CURRENT_A := extraA,
        CFG := uut.CFG);
    uut.inputs.CELL_PIN_V := sim.CELL_PIN_V;
    uut.inputs.LOAD_PIN_V := sim.LOAD_PIN_V;
    uut.clock.NOW_MS := now;
    uut();
    now := now + 20;
    IF uut.state = ST_FAULT THEN EXIT; END_IF;
  END_FOR;
  ASSERT_TRUE(uut.state = ST_FAULT);
  ASSERT_EQ(uut.LAST_RESULT, 'Fault');
  ASSERT_TRUE(uut.LAST_STATUS = TS_OVER_CURRENT);
  ASSERT_EQ(uut.outputs.LOAD_SET_V, 0.0);

  (* Stays in fault, flashing red at 5 Hz, while the cell is present. *)
  FOR k := 1 TO 100 DO
    sim(PRESENT := present, OCV_V := ocv, IR_OHM := ir,
        LOAD_SET_V := uut.outputs.LOAD_SET_V, EXTRA_CURRENT_A := extraA,
        CFG := uut.CFG);
    uut.inputs.CELL_PIN_V := sim.CELL_PIN_V;
    uut.inputs.LOAD_PIN_V := sim.LOAD_PIN_V;
    uut.clock.NOW_MS := now;
    uut();
    now := now + 20;
    ASSERT_TRUE(uut.state = ST_FAULT);
    ASSERT_EQ(uut.outputs.LOAD_SET_V, 0.0);
    ASSERT_EQ(uut.outputs.LED_G, 0);
    IF uut.outputs.LED_R > 0 THEN
      litScans := litScans + 1;
    ELSE
      darkScans := darkScans + 1;
    END_IF;
  END_FOR;
  ASSERT_EQ(litScans, 50);
  ASSERT_EQ(darkScans, 50);
  ASSERT_EQ(uut.TEST_COUNT, 1);

  present := FALSE;
  FOR k := 1 TO 2 DO
    sim(PRESENT := present, OCV_V := ocv, IR_OHM := ir,
        LOAD_SET_V := uut.outputs.LOAD_SET_V, EXTRA_CURRENT_A := extraA,
        CFG := uut.CFG);
    uut.inputs.CELL_PIN_V := sim.CELL_PIN_V;
    uut.inputs.LOAD_PIN_V := sim.LOAD_PIN_V;
    uut.clock.NOW_MS := now;
    uut();
    now := now + 20;
  END_FOR;
  ASSERT_TRUE(uut.state = ST_READY);
END_TEST

TEST 'Cell pulled during the test returns to ready'
VAR
  k : INT;
END_VAR
  MOCK uut.clock;
  present := TRUE;
  FOR k := 1 TO 400 DO
    IF k = 20 THEN
      present := FALSE;
    END_IF;
    sim(PRESENT := present, OCV_V := ocv, IR_OHM := ir,
        LOAD_SET_V := uut.outputs.LOAD_SET_V, EXTRA_CURRENT_A := extraA,
        CFG := uut.CFG);
    uut.inputs.CELL_PIN_V := sim.CELL_PIN_V;
    uut.inputs.LOAD_PIN_V := sim.LOAD_PIN_V;
    uut.clock.NOW_MS := now;
    uut();
    now := now + 20;
    IF uut.TEST_COUNT > 0 THEN EXIT; END_IF;
  END_FOR;
  ASSERT_TRUE(uut.state = ST_READY);
  ASSERT_EQ(uut.LAST_RESULT, 'Removed');
  ASSERT_TRUE(uut.LAST_STATUS = TS_CELL_REMOVED);
END_TEST
