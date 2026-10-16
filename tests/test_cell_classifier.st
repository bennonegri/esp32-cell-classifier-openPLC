SETUP
VAR
  cfg : TESTER_CONFIG;
  c : CELL_CLASSIFIER;
END_VAR
END_SETUP

TEST 'Typical readings match their chemistry'
  c(OCV_V := 1.50, IR_OHM := 0.150, IR_VALID := TRUE, CFG := cfg);
  ASSERT_TRUE(c.MATCHED);
  ASSERT_EQ(c.INDEX, 1);
  ASSERT_EQ(c.NAME, 'AA Alkaline');
  ASSERT_NEAR(c.SCORE, 0.0, 0.0001);
  ASSERT_EQ(c.COLOR.G, 80);

  c(OCV_V := 1.32, IR_OHM := 0.040, IR_VALID := TRUE, CFG := cfg);
  ASSERT_EQ(c.NAME, 'AA NiMH');

  c(OCV_V := 3.80, IR_OHM := 0.150, IR_VALID := TRUE, CFG := cfg);
  ASSERT_EQ(c.NAME, '14500 Li-ion');
  ASSERT_EQ(c.COLOR.B, 255);

  c(OCV_V := 3.28, IR_OHM := 0.080, IR_VALID := TRUE, CFG := cfg);
  ASSERT_EQ(c.NAME, '14500 LiFePO4');
  ASSERT_EQ(c.COLOR.R, 160);
END_TEST

TEST 'IR separates cells with overlapping OCV'
  (* 1.40 V is 0.83 sigma from alkaline and 1 sigma from NiMH, so OCV
     alone picks alkaline; a NiMH-like IR flips it. *)
  c(OCV_V := 1.40, IR_OHM := 0.0, IR_VALID := FALSE, CFG := cfg);
  ASSERT_EQ(c.NAME, 'AA Alkaline');
  c(OCV_V := 1.40, IR_OHM := 0.035, IR_VALID := TRUE, CFG := cfg);
  ASSERT_EQ(c.NAME, 'AA NiMH');
END_TEST

TEST 'Score matches the firmware formula'
  (* Alkaline: ((1.6 - 1.5) / 0.12)^2 + (ln(0.3 / 0.15) / ln 2)^2 = 1.6944 *)
  c(OCV_V := 1.6, IR_OHM := 0.3, IR_VALID := TRUE, CFG := cfg);
  ASSERT_EQ(c.INDEX, 1);
  ASSERT_NEAR(c.SCORE, 1.6944, 0.001);
END_TEST

TEST 'Far from every profile is unknown but keeps the score'
  c(OCV_V := 2.4, IR_OHM := 0.1, IR_VALID := TRUE, CFG := cfg);
  ASSERT_FALSE(c.MATCHED);
  ASSERT_EQ(c.INDEX, 0);
  ASSERT_EQ(c.NAME, 'Unknown');
  ASSERT_GT(c.SCORE, cfg.MAX_MATCH_SCORE);
  ASSERT_EQ(c.COLOR.R, 0);
END_TEST

TEST 'Zero or negative IR is floored, not a math error'
  c(OCV_V := 1.32, IR_OHM := -0.01, IR_VALID := TRUE, CFG := cfg);
  ASSERT_TRUE(c.MATCHED);
  ASSERT_EQ(c.NAME, 'AA NiMH');
  ASSERT_LT(c.SCORE, 10.0);
END_TEST
