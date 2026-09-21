debounce testbench — how it works



1\. This testbench verifies the debounce module. It covers four behaviors: a clean press committing to btn\_clean, a short bounce being correctly ignored, btn\_pulse firing once on press, and btn\_pulse staying silent on release.



2\. By default the COUNT\_MAX is 2,000,000 ticks. In the testbench I override to 200, so its dont take much time needed to simulate the entire compute. 200 is consider due to its perfect time frame allow all the logic to execute accordingly, rather than 5 which is too small count, could end the compute before all the logic executed. The logic is identical only the count threshold shrinks. So the debounce behaves exactly the same, just faster to simulate. 



3\. 

Test 1 : Verified the design really register user input (btn\_in) after finish all the COUNT\_MAX. 

Test 2 : Verified the design do not register sudden bouce in the button (btn\_in) by not register the sudden input if it not last at least 200 (COUNT\_MAX). Ignore input that doesn't last COUNT\_MAX 


Test 3 : Verified the btn\_pulse only fire when the btn\_in transition (0 to 1). There is flag (pulse\_seen) shows the btn\_pulse fires for one cycle when the count completes, around 200-201, including synchronizer latency; the pulse\_seen flag latches high to confirm it fired.  



Test 4 : Verified the btn-pulse do not fire during the release btn\_in transition (1 to 0). no btn\_pulse transition is visible at any count.

4. During the first Test 2 run the MISMATCH check fires btn-clean 1 when expected is 0 . I opened the waveform and sees the btn\_clean stick to 1 due to previous test simulation. To overcome this issue I run btn\_in 0 for 250 cycles on every beginning of test to ensure the btn\_in reset to 0 before every test and kill the gray area on every test. 

5. In this testbench sticky flag is used to catch one-cycle signal. The sticky flag records the transient, latching high the instant the pulse fires, so a one-cycle event cant't slip past between checks. This method works for any hard-to-catch transient: interrupts, error strobes, or single-cycle handshakes.  






