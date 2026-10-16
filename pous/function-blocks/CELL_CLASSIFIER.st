(* Cell chemistry classification from OCV and internal resistance (IR).

   Each chemistry has a typical OCV and IR with a 1-sigma spread. A reading
   is scored by its squared normalised distance from each profile:
     score = ((OCV - typ) / sigma)^2 + IR_WEIGHT * (ln(IR / typ) / ln(k))^2
   IR is compared on a log scale because it varies by multiples, not
   offsets. The lowest score wins; above MAX_MATCH_SCORE the cell is
   unknown. With IR_VALID false the cell is classified on OCV alone. *)

FUNCTION_BLOCK CELL_CLASSIFIER
VAR_INPUT
  OCV_V : REAL;
  IR_OHM : REAL;
  IR_VALID : BOOL;
  CFG : TESTER_CONFIG;
END_VAR
VAR_OUTPUT
  MATCHED : BOOL;
  INDEX : INT; // 1-based index into PROFILES, 0 if unknown
  NAME : STRING; // profile name, or 'Unknown'
  SCORE : REAL; // best match score, kept even when unknown; lower is closer
  COLOR : RGB; // result colour, black if unknown
END_VAR
VAR CONSTANT
  (* Typical resting values for healthy cells. OCV spreads cover the usable
     state of charge. IR is DC resistance at ~1 s; it varies a lot by brand
     and age, so it has a wide spread. *)
  PROFILES : ARRAY[1..4] OF CELL_PROFILE := [
    (NAME := 'AA Alkaline', OCV_TYP_V := 1.50, OCV_SIGMA_V := 0.12,
     IR_TYP_OHM := 0.150, IR_SPREAD_K := 2.0, COLOR := (R := 255, G := 80, B := 0)),
    (NAME := 'AA NiMH', OCV_TYP_V := 1.32, OCV_SIGMA_V := 0.08,
     IR_TYP_OHM := 0.040, IR_SPREAD_K := 2.0, COLOR := (R := 255, G := 255, B := 255)),
    (NAME := '14500 Li-ion', OCV_TYP_V := 3.80, OCV_SIGMA_V := 0.25,
     IR_TYP_OHM := 0.150, IR_SPREAD_K := 2.0, COLOR := (R := 0, G := 0, B := 255)),
    (NAME := '14500 LiFePO4', OCV_TYP_V := 3.28, OCV_SIGMA_V := 0.08,
     IR_TYP_OHM := 0.080, IR_SPREAD_K := 2.0, COLOR := (R := 160, G := 0, B := 255))
  ];
  MIN_IR_OHM : REAL := 0.005; // floor for the log IR term; noise can give ~0 or negative IR
END_VAR
VAR
  i : INT;
  ocvZ : REAL;
  irZ : REAL;
  candidate : REAL;
END_VAR

INDEX := 0;
SCORE := 0.0;
FOR i := 1 TO 4 DO
  ocvZ := (OCV_V - PROFILES[i].OCV_TYP_V) / PROFILES[i].OCV_SIGMA_V;
  candidate := ocvZ * ocvZ;
  IF IR_VALID THEN
    irZ := LN(MAX(IR_OHM, MIN_IR_OHM) / PROFILES[i].IR_TYP_OHM)
           / LN(PROFILES[i].IR_SPREAD_K);
    candidate := candidate + CFG.IR_WEIGHT * irZ * irZ;
  END_IF;
  IF INDEX = 0 OR candidate < SCORE THEN
    INDEX := i;
    SCORE := candidate;
  END_IF;
END_FOR;

(* Keep the score for the log, but report no match if it's too far off. *)
MATCHED := SCORE <= CFG.MAX_MATCH_SCORE;
IF MATCHED THEN
  NAME := PROFILES[INDEX].NAME;
  COLOR := PROFILES[INDEX].COLOR;
ELSE
  INDEX := 0;
  NAME := 'Unknown';
  COLOR.R := 0;
  COLOR.G := 0;
  COLOR.B := 0;
END_IF;

END_FUNCTION_BLOCK
