# Air-Trace — Design Verification Portfolio

Independent SystemVerilog verification of a tilt-controlled FPGA drawing game
(Nexys A7-100T). The RTL is a collaborative academic design; the verification
environment — testbenches, reference models, scoreboards, and directed +
constrained-random tests — is my own independent work.

## Why this project
Design Verification is about proving RTL you didn't write behaves to spec. This
repo takes a multi-module system (accelerometer SPI master, control FSMs, a
BRAM canvas, a similarity-scoring datapath, VGA timing) and builds self-checking
verification around it — including a real bug found and localized in the
similarity engine.

## Verified modules

| Module | Techniques | Status |
|--------|-----------|--------|
| `tilt_decoder` | reference model, self-checking scoreboard, directed + constrained-random, fault injection | ✅ Complete |
| `game_timer` | parameter override for fast sim, directed timing tests, SVA-style checks; found an unspecified start/stop priority | ✅ Complete |
| `debounce` | metastability/bounce filtering, sticky-flag pulse catcher, cross-test isolation, press-only asymmetry check | ✅ Complete |
| `similarity_calc` | reactive driver (BRAM-latency model), valid/ready handshake, IoU scoreboard, mode-selected patterns; **found an overlap-boundary bug** | ✅ Complete |
| `game_fsm` | FSM state/transition coverage | 🚧 Planned |
| `accelerometer_spi_master` | SPI protocol, reactive slave BFM, protocol assertions | 🚧 Planned |

## Findings
Real issues surfaced by the testbenches (see `docs/bug_log.md`):
- **game_timer** — start/stop priority is unspecified by the spec; RTL resolves stop-wins. Flagged for clarification.
- **similarity_calc** — overlap undercounted at target row boundaries (1 cell per boundary row, canvas-independent). Reproduced and localized; DUT-bug vs test-model root cause pending.

## Verification techniques demonstrated
- Independent, spec-based reference models and self-checking scoreboards
- Directed corner-case + constrained-random stimulus
- Fault injection (proving the testbench catches seeded bugs)
- Parameter override to make billion-cycle timing simulatable
- Reactive drivers modeling memory read latency
- Valid/ready handshake synchronization
- Waveform-based debugging and systematic fault localization

## Structure
- `rtl/` — design under test (academic group project)
- `tb/` — testbenches (my work)
- `docs/` — notes, bug log, and a DV handbook
- `sim/` — simulation logs