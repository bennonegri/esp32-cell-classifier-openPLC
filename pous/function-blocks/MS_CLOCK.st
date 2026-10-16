(* Free-running millisecond clock, the PLC equivalent of millis(). Wraps
   after ~49 days like millis(), so compare times as NOW_MS - start, which
   UDINT arithmetic keeps correct across the wrap. Call once per scan. *)

FUNCTION_BLOCK MS_CLOCK
VAR_OUTPUT
  NOW_MS : UDINT;
END_VAR
VAR
  tick : TON;
  baseMs : UDINT;
END_VAR

(* A TON's elapsed time stops at PT, so restart it every hour and carry
   the hour into baseMs. The fraction of a scan past the hour is lost,
   which is negligible. *)
tick(IN := TRUE, PT := T#1h);
IF tick.Q THEN
  baseMs := baseMs + 3600000;
  tick(IN := FALSE);
  tick(IN := TRUE, PT := T#1h);
END_IF;
NOW_MS := baseMs + TIME_TO_UDINT(tick.ET);

END_FUNCTION_BLOCK
