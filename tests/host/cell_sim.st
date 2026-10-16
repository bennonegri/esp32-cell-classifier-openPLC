(* Simulated cell, divider and electronic load. The load holds LOAD_SET_V
   across RL (if the cell has the headroom), so it draws
   LOAD_SET_V / RL plus any EXTRA_CURRENT_A fault current, and the
   terminal voltage drops by I x IR. Outputs are ADC pin voltages. *)

FUNCTION_BLOCK CELL_SIM
VAR_INPUT
  PRESENT : BOOL;
  OCV_V : REAL;
  IR_OHM : REAL;
  LOAD_SET_V : REAL;
  EXTRA_CURRENT_A : REAL;
  CFG : TESTER_CONFIG;
END_VAR
VAR_OUTPUT
  CELL_V : REAL; // terminal voltage
  CELL_PIN_V : REAL;
  LOAD_PIN_V : REAL;
END_VAR
VAR
  currentA : REAL;
END_VAR

IF PRESENT THEN
  currentA := LOAD_SET_V / CFG.LOAD_RESISTOR_OHM + EXTRA_CURRENT_A;
  CELL_V := OCV_V - currentA * IR_OHM;
ELSE
  currentA := 0.0;
  CELL_V := 0.0;
END_IF;
LOAD_PIN_V := currentA * CFG.LOAD_RESISTOR_OHM;
CELL_PIN_V := CELL_V / CFG.CELL_CAL_GAIN * CFG.DIVIDER_R_BOTTOM_OHM
              / (CFG.DIVIDER_R_TOP_OHM + CFG.DIVIDER_R_BOTTOM_OHM);

END_FUNCTION_BLOCK
