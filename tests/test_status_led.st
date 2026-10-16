SETUP
VAR
  led : STATUS_LED;
  red : RGB;
  green : RGB;
  t : UDINT;
END_VAR
  red.R := 255;
  green.G := 255;
END_SETUP

TEST 'Solid colour is scaled by brightness like NeoPixel'
  led(NOW_MS := 0, COLOR := red, FLASH_HZ := 0.0, BRIGHTNESS := 64);
  ASSERT_TRUE(led.LIT);
  ASSERT_EQ(led.R, 64);
  ASSERT_EQ(led.G, 0);
  led(NOW_MS := 10000, COLOR := red, FLASH_HZ := 0.0, BRIGHTNESS := 255);
  ASSERT_EQ(led.R, 255);
END_TEST

TEST 'Flash is on for the first half of each period'
  (* 5 Hz: 200 ms period, on for 0-99 ms. *)
  led(NOW_MS := 1000, COLOR := red, FLASH_HZ := 5.0, BRIGHTNESS := 255);
  ASSERT_TRUE(led.LIT);
  led(NOW_MS := 1099, COLOR := red, FLASH_HZ := 5.0, BRIGHTNESS := 255);
  ASSERT_TRUE(led.LIT);
  led(NOW_MS := 1100, COLOR := red, FLASH_HZ := 5.0, BRIGHTNESS := 255);
  ASSERT_FALSE(led.LIT);
  ASSERT_EQ(led.R, 0);
  led(NOW_MS := 1200, COLOR := red, FLASH_HZ := 5.0, BRIGHTNESS := 255);
  ASSERT_TRUE(led.LIT);
  ASSERT_EQ(led.R, 255);
END_TEST

TEST 'Changing colour restarts the flash on'
  led(NOW_MS := 0, COLOR := red, FLASH_HZ := 3.0, BRIGHTNESS := 255);
  led(NOW_MS := 200, COLOR := red, FLASH_HZ := 3.0, BRIGHTNESS := 255);
  ASSERT_FALSE(led.LIT);
  led(NOW_MS := 210, COLOR := green, FLASH_HZ := 3.0, BRIGHTNESS := 255);
  ASSERT_TRUE(led.LIT);
  ASSERT_EQ(led.G, 255);
END_TEST
