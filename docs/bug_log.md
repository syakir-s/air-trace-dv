Finding 2 — game\_timer: start/stop priority is unspecified



When start\_timer and stop\_timer are asserted on the same clock edge, the RTL resolves stop-wins: running stays 0 and the timer never starts. This happens because if(stop\_timer) running<=0 is the later non-blocking assignment in the always block, so it overrides the earlier if(start\_timer) running<=1. The spec does not define behavior for simultaneous assertion. Verified with a directed test by forced both signals high on one edge, ran 300 cycles, confirmed seconds held at 0. Flagged for spec clarification.

