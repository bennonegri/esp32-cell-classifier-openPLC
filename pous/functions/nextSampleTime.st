(* Time of the sample just taken on a fixed cadence: the previous sample
   time plus the interval. If the scan fell a whole interval behind, the
   cadence restarts from now instead of catching up with back-to-back
   samples. *)

FUNCTION nextSampleTime : UDINT
VAR_INPUT
  LAST_MS : UDINT; // previous sample time
  NOW_MS : UDINT;
  INTERVAL_MS : UDINT;
END_VAR

nextSampleTime := LAST_MS + INTERVAL_MS;
IF NOW_MS - nextSampleTime >= INTERVAL_MS THEN
  nextSampleTime := NOW_MS;
END_IF;

END_FUNCTION
