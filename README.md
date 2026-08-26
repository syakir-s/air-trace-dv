# Air-Trace — Design Verification Portfolio

Independent SystemVerilog verification of a tilt-controlled FPGA drawing game
(Nexys A7-100T). The RTL is a collaborative academic design; the verification
environment — testbenches, reference models, coverage, and assertions — is my
own work.

## Verified modules
- **tilt_decoder** — reference model, self-checking scoreboard, directed +
  constrained-random stimulus, fault injection. ✅ Complete

## Structure
- `rtl/` — design under test (academic group project)
- `tb/` — testbenches (my work)
- `docs/` — notes and bug log
- `sim/` — simulation logs