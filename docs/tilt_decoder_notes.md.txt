tilt_decoder testbench — how it works

1. This testbench verifies the tilt_decoder module. It drives an acl_data input and checks that tilt_x and tilt_y match the spec, including the deadzone rule, where any value within ±DEADZONE must output 0. Every vector is checked by comparing the DUT's output against a reference model.

2. The reference model is written independently from the RTL, from the spec only and not from the designer's code. This independence is the point: if the RTL deviates from the spec, the model and DUT disagree and the bug surfaces. A model copied from the RTL would inherit the same bug and pass anyway.

3. Two kinds of stimulus are used. Directed tests hand-pick known-dangerous corners (deadzone edges, most-negative value, zero). Constrained-random ($urandom) fires many vectors to catch corners I didn't think to hand-pick. Each covers what the other misses, that's why both are used.

4. signed is used because both axes carry positive and negative values, and two's-complement comparisons only work correctly on signed variables. !== is used instead of != because it detects X (unknown) values, if the DUT ever outputs an uninitialized/garbage bit, the checker catches it rather than letting it slip through.

5. To prove the testbench actually works, I deliberately injected a fault in the DUT — breaking the sign extension ({1'b0, x_raw} instead of {x_raw[4], x_raw}). On rerun, the scoreboard flagged every negative-value vector as a mismatch (expected -16, got +16) while positives still passed — the failure pattern matched the injected fault exactly. This confirms the checker can catch real bugs, not just print PASS. I then restored the correct RTL.