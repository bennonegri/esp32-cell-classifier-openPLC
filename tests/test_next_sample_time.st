TEST 'Keeps a fixed cadence on a coarser scan'
  (* 50 ms checks on a 20 ms scan land at 60, 100, 160, 200 ms. *)
  ASSERT_EQ(nextSampleTime(LAST_MS := 0, NOW_MS := 60, INTERVAL_MS := 50), 50);
  ASSERT_EQ(nextSampleTime(LAST_MS := 50, NOW_MS := 100, INTERVAL_MS := 50), 100);
  ASSERT_EQ(nextSampleTime(LAST_MS := 100, NOW_MS := 160, INTERVAL_MS := 50), 150);
END_TEST

TEST 'Restarts from now after falling an interval behind'
  ASSERT_EQ(nextSampleTime(LAST_MS := 0, NOW_MS := 130, INTERVAL_MS := 50), 130);
END_TEST

TEST 'Works across the millisecond counter wrap'
  ASSERT_EQ(nextSampleTime(LAST_MS := 4294967270, NOW_MS := 30, INTERVAL_MS := 50), 24);
END_TEST
