# Air-Trace — Design Verification Portfolio

Independent SystemVerilog verification of a tilt-controlled FPGA drawing game
(Nexys A7-100T). The RTL is a collaborative academic design; the verification
environment — testbenches, reference models, scoreboards, coverage, and
directed + constrained-random tests — is my own independent work.

**6 of 6 target modules verified**, with 3 real bugs found and localized.

## Why this project
Design Verification is about proving RTL you didn't write behaves to spec. This
repo takes a multi-module system (accelerometer SPI master, control FSMs, a
BRAM canvas, a similarity-scoring datapath, VGA timing) and builds self-checking
verification around it — including real bugs found and localized in the
similarity engine and the SPI read path.

## Verified modules

| Module | Techniques | Status |
|--------|-----------|--------|
| `tilt_decoder` | reference model, self-checking scoreboard, directed + constrained-random, fault injection | ✅ Complete |
| `game_timer` | parameter override for fast sim, directed timing tests; found an unspecified start/stop priority | ✅ Complete |
| `debounce` | metastability/bounce filtering, sticky-flag pulse catcher, cross-test isolation, press-only asymmetry check | ✅ Complete |
| `similarity_calc` | reactive driver (BRAM-latency model), valid/ready handshake, IoU scoreboard, mode-selected patterns; **found an overlap-boundary bug** | ✅ Complete |
| `game_fsm` | FSM state coverage + transition coverage; one continuous transition walk | ✅ Complete |
| `accelerometer_spi_master` | reactive SPI slave BFM (mode-0), serial data-capture verification; diagnosed a bit-alignment off-by-one | ✅ Complete |

## Findings
Real issues surfaced by the testbenches (see `docs/bug_log.md`):
- **game_timer** — start/stop priority is unspecified by the spec; RTL resolves stop-wins. Flagged for clarification.
- **similarity_calc** — overlap undercounted at target row boundaries (1 cell per boundary row, canvas-independent). Reproduced and localized; DUT-bug vs test-model root cause pending.
- **game_fsm** — stimulus race: inputs driven on the clock edge were missed by the FSM; fixed by driving after the edge. Testbench-methodology finding, documented.

## Verification techniques demonstrated
- Independent, spec-based reference models and self-checking scoreboards
- Directed corner-case + constrained-random stimulus
- Fault injection (proving the testbench catches seeded bugs)
- Parameter override to make billion-cycle timing simulatable
- Reactive drivers modeling memory read latency
- Reactive slave BFM obeying SPI mode-0 protocol timing
- Valid/ready handshake synchronization
- FSM state and transition coverage (coverage-driven closure)
- Waveform-based debugging and systematic fault localization

## Structure
- `rtl/` — design under test (academic group project)
- `tb/` — testbenches (my work)
- `docs/` — notes, bug log, and a DV handbook
- `sim/` — simulation logs