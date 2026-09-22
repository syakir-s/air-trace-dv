game_fsm testbench - how it works

1. This testbench verify the game_fsm module. In this testbench 6 different patterns of transition is tested. The transition is shifted based on changes in user input (rst, start_btn, submit_btn, score_ready, next_btn, timer_done).
2. coverage is use to flag if the changes make really shift the state to other state (legally) and to ensure all state visited at the end of test allow easy debugging. state_coverage allow me to check if all state (5 state) is visited at the end of final test, while transition coverage flag all legal transition (6 types) allow clear visibility and easy debugging.
3. S_SCORE has two exit transitions depending on shape_count, so the test loops through all 4 shapes to exercise both. The loop-back on shapes 1–3 and the game-over on shape
4. A button pulse driven on the clock edge raced with the FSM's sampling. The FSM read the old value and the pulse was missed, so the FSM stayed in IDLE. Diagnosed from the waveform (the pulse fell between clock edges). Fixed with a #1 delay after each @(posedge clk) so inputs are stable before the next sampling edge.
5. Rather than isolating each test like in the earlier testbenches, in this testbench all the test is run in one go (no reset condition from initial test to last test) without restart in the start of each condition. This is done to test the ability of the design to make correct transition based on every condition.


 
