(* Status LED colour: solid, or flashing at a 50% duty cycle starting on.
   The flash phase restarts whenever the colour or rate changes. Outputs
   are scaled by BRIGHTNESS the same way Adafruit_NeoPixel does it. *)

FUNCTION_BLOCK STATUS_LED
VAR_INPUT
  NOW_MS : UDINT;
  COLOR : RGB; // (0, 0, 0) is off
  FLASH_HZ : REAL; // 0 = solid
  BRIGHTNESS : USINT; // 0-255
END_VAR
VAR_OUTPUT
  R : USINT;
  G : USINT;
  B : USINT;
  LIT : BOOL; // TRUE in the on half of a flash, or when solid
END_VAR
VAR
  lastColor : RGB;
  lastHz : REAL := -1.0;
  flashStartMs : UDINT;
  periodMs : UDINT;
END_VAR

IF COLOR.R <> lastColor.R OR COLOR.G <> lastColor.G
    OR COLOR.B <> lastColor.B OR FLASH_HZ <> lastHz THEN
  lastColor := COLOR;
  lastHz := FLASH_HZ;
  flashStartMs := NOW_MS;
END_IF;

IF FLASH_HZ > 0.0 THEN
  periodMs := MAX(REAL_TO_UDINT(1000.0 / FLASH_HZ), 2);
  LIT := (NOW_MS - flashStartMs) MOD periodMs < periodMs / 2;
ELSE
  LIT := TRUE;
END_IF;

IF LIT THEN
  R := UINT_TO_USINT(USINT_TO_UINT(COLOR.R) * (USINT_TO_UINT(BRIGHTNESS) + 1) / 256);
  G := UINT_TO_USINT(USINT_TO_UINT(COLOR.G) * (USINT_TO_UINT(BRIGHTNESS) + 1) / 256);
  B := UINT_TO_USINT(USINT_TO_UINT(COLOR.B) * (USINT_TO_UINT(BRIGHTNESS) + 1) / 256);
ELSE
  R := 0;
  G := 0;
  B := 0;
END_IF;

END_FUNCTION_BLOCK
