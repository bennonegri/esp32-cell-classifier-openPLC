SETUP
VAR
  clk : MS_CLOCK;
END_VAR
END_SETUP

TEST 'Counts milliseconds'
  clk();
  ASSERT_EQ(clk.NOW_MS, 0);
  ADVANCE_TIME(1234000000);
  clk();
  ASSERT_EQ(clk.NOW_MS, 1234);
END_TEST

TEST 'Keeps counting past the hourly timer restart'
  clk();
  ADVANCE_TIME(3599000000000);
  clk();
  ASSERT_EQ(clk.NOW_MS, 3599000);
  ADVANCE_TIME(1000000000);
  clk();
  ASSERT_EQ(clk.NOW_MS, 3600000);
  ADVANCE_TIME(2500000000);
  clk();
  ASSERT_EQ(clk.NOW_MS, 3602500);
END_TEST
