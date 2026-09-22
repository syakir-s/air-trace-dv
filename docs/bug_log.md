**Finding 1 — game\_timer: start/stop priority is unspecified**



When start\_timer and stop\_timer are asserted on the same clock edge, the RTL resolves stop-wins: running stays 0 and the timer never starts. This happens because if(stop\_timer) running<=0 is the later non-blocking assignment in the always block, so it overrides the earlier if(start\_timer) running<=1. The spec does not define behavior for simultaneous assertion. Verified with a directed test by forced both signals high on one edge, ran 300 cycles, confirmed seconds held at 0. Flagged for spec clarification.



**Finding 2 - similarity\_calc: undercounts overlap at target row boundaries**



Symptom: When test\_mode is set to MODE\_SCRIBBLE and MODE\_MATCH the system return wrong score (MODE\_SCRIBBLE: system return score = 48 (expected value is 50) / MODE\_MATCH: system return score = 95 (expected value is 100)). This situation didnt occur when test\_mode is set to MODE\_ONES and MODE\_LEFT.



Diagnosis: Analysis on timing diagram reveal correct expected value for both target\_cnt and drawn\_cnt (expected : target\_cnt = 1200 , drawn\_cnt = 2400), but wrong overlap value (overlap = 1170) short by 30 while the expected value is 1200. The target box spans 30 rows (cell\_y < 30), so the loss is one overlap cell per target row.



Key isolation: MODE\_SCRIBBLE (canvas = left half) and MODE\_MATCH (canvas = same box as target) have DIFFERENT canvas patterns but the SAME target box, and both produce the identical overlap = 1170. This proves the loss depends only on the target boundary, not on the canvas pattern.



Status: Reproduced and localized to overlap undercount at target row boundaries (\~1 cell per boundary row). Root cause not yet confirmed — open question whether the misalignment is in the DUT's acc\_en/target\_d pipeline logic (real hardware bug) or in the testbench reactive driver's latency model (test artifact). Next step: waveform inspection at a single target-boundary row transition to compare canvas\_bit vs target\_d alignment


**Finding 3 - game\_fsm: stimulus race on clock edge**


Driving button inputs on the same instant as @(posedge clk) caused a race: the FSM sampled the old value and the pulse missed the edge, so the FSM never left IDLE. Diagnosed via waveform (pulse visibly fell between clock edges). Fixed by driving inputs just after the edge (#1 offset / pulse task) so they're stable when the DUT samples on the next edge.

