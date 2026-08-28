game\_timer testbench — how it works



1\. This testbench verifies the game\_timer module. Behaviour test in this test bench is basic counting, saturation at LIMIT\_SEC and start/stop conflict.



2\. By default the timer counts 100,000,000 ticks before advancing one second. In the testbench I override CLK\_HZ to 100, so it only counts 100 ticks per second which the logic is identical, only the count threshold shrinks, so the timer behaves exactly the same but simulates fast instead of taking billions of cycles.



3\. 

Test 1 : Verified the design run compute correct second, by ran the test for 250 ticks. Which by right the test should give output of 2 second with calculation (250/100 = 2.5 \~ 2).



Test 2 : Verified the timer limit of the design. By default the timer will stop at 60 seconds ( due to LIMIT\_SEC = 60 ). The variable observe is timer\_done, which should be high after 6000 ticks. The test runs for 6050 ticks to give margin to verified the timer\_done state. 



Test 3 : The RTL resolves stop-wins because the stop assignment is the later of two non-blocking assignments to running, so it overrides the start assignment on that edge. I confirmed this empirically — forced both high, ran 300 cycles, and seconds stayed 0.



4\. In TEST 3, seconds kept reading 60 instead of 0. I opened the waveform and saw seconds stuck at 3c (60) even after my reset pulse, the reset wasn't clearing it. The cause was cross-test contamination: TEST 2 left the timer saturated at 60 with start\_timer still high, and my one-cycle reset pulse was too narrow to override it. I fixed it by widening the reset (holding it several cycles and letting it settle) and adding a check\_seconds(0) immediately after reset to verify a clean slate before running the conflict test. This isolated the failure — proving whether the reset or the conflict was at fault. 



5\. In tilt\_decoder\_tb I inserted multiple pattern of input to observe the output while in this test bench I let system run the cycle and checked the output at specific cycles using hand-computed expected values (2, 60, 0) which directed timing tests, versus tilt\_decoder's automatic reference model.

