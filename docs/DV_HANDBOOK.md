# Design Verification Handbook

*A practical field guide for verifying RTL, built from the Air-Trace project.*

This handbook is written for future-me. It captures the reasoning, the reusable
patterns, and the Vivado workflow I learned verifying all six Air-Trace modules
(`tilt_decoder`, `game_timer`, `debounce`, `similarity_calc`, `game_fsm`,
`accelerometer_spi_master`), so I can verify the next module independently. Read
it once end-to-end; after that, use it as a reference.

The examples are all real — they come from testbenches I wrote and debugged.

---

## Part 0 — What verification actually is

Design Verification (DV) is the job of **proving that RTL behaves the way the
spec says it should** — and finding the places where it doesn't. The design
engineer writes the RTL; the DV engineer tries to break it.

The single most important mental model:

> **Two independent things are fed the same stimulus. If they disagree, there's a bug.**

- The **DUT** (Design Under Test) is the RTL — one interpretation of the spec.
- The **reference model** is a second, independent interpretation of the *same
  spec*, written by me in the testbench.
- The **checker/scoreboard** compares the two, every cycle or every transaction.

When they disagree, either the DUT is wrong or my model is wrong — and running
that disagreement down *is the job*.

A testbench that only ever prints PASS has proven nothing until I've also proven
it can *fail* (see Part 6, fault injection). "All PASS" and "my checker is
blind" look identical from the outside.

---

## Part 1 — The independence principle (the heart of it all)

The reference model must be **independent** of the RTL. Its idea of "correct"
must come from a *different source* than the code it checks — the spec, the
datasheet, the requirement — never the designer's code.

**Why it matters:** if I build my reference model by copying the DUT's logic,
then when the designer made a mistake, I copy the same mistake. Expected equals
actual. The scoreboard reports PASS. The bug ships.

> The RTL is one interpretation of the spec. The reference model is a second,
> independent interpretation of the same spec. Verification is the collision
> between them.

This is why, in real teams, design and DV are often different people working
from the *same spec independently*. Two independent implementations are unlikely
to be wrong in the same way.

**The test for every checker I write:** *if the DUT were wrong, would my checker
still be right?* If the answer is no, the checker is theatre.

---

## Part 2 — Anatomy of a testbench

Almost every testbench I write — up to full UVM — is this same skeleton with
fancier versions of each block:

```
signals  ->  DUT instance  ->  clock  ->  reference model  ->  checker  ->  stimulus
```

1. **Signals** — one variable per DUT port.
2. **DUT instance** — instantiate the design, with parameter overrides.
3. **Clock generator** — `always #5 clk = ~clk;` (10 ns period).
4. **Reference model** — computes the expected answer, independently.
5. **Checker/scoreboard** — compares expected vs actual, logs mismatches.
6. **Stimulus** — the `initial` block that drives inputs and calls checks.

### The minimal template

```systemverilog
`timescale 1ns/1ps

module my_module_tb;

  // --- parameters (override big constants for fast sim) ---
  localparam PARAM = 100;

  // --- signals: match DUT port widths ---
  logic        clk;
  logic [7:0]  in_signal;    // driven by TB
  logic [7:0]  out_signal;   // read from DUT (no initializer)

  // --- DUT ---
  my_module #(.PARAM(PARAM)) dut (
    .clk(clk),
    .in_signal(in_signal),
    .out_signal(out_signal)
  );

  // --- clock ---
  always #5 clk = ~clk;

  // --- reference model / helper tasks ---
  // (see Part 4)

  // --- checker ---
  task automatic check(input [7:0] expected);
      #1;
      if (out_signal !== expected)
          $error("MISMATCH: got=%d expected=%d", out_signal, expected);
      else
          $display("PASS: out=%d", out_signal);
  endtask

  // --- stimulus ---
  initial begin
    clk = 0; in_signal = 0;
    // ... tests ...
    $display("Tests done.");
    $finish;
  end

endmodule
```

### Rules baked into the template

- **A signal I only *read* from the DUT** is declared to match the DUT's width
  and is **never initialized** by me — the DUT drives it. Only signals *I drive*
  get initial values.
- **`clk = 0;`** is the first line of the `initial` block, so the clock starts
  from a known value instead of `x`.
- **First thing after copy-pasting a template: fix the module name** in the DUT
  instantiation. This is the #1 copy-paste bug (I hit it every single time).

---

## Part 3 — The language essentials (SystemVerilog for TB)

I do **not** memorize syntax. I look it up, every time, forever — that's the
job. What I keep in my head is *what* to write, not the exact characters. This
table is the vocabulary I actually use.

### `logic` vs `reg`

- Verilog RTL uses `reg` (assigned in a procedural block) and `wire`
  (continuous). `reg` does *not* mean a hardware register — it's a naming
  accident.
- SystemVerilog testbenches use **`logic`** — the modern replacement. More
  flexible (drivable procedurally *or* continuously) and it doesn't lie about
  hardware.
- Both are **4-state** (0, 1, X, Z). This matters — see `!==` below.
- File extension decides the language: **RTL in `.v` (Verilog), testbench in
  `.sv` (SystemVerilog).** Mixing them in one project is normal and standard.
  A `logic` in a `.v` file throws a syntax error — because `.v` is compiled as
  old Verilog.

### `signed`

- By default variables are **unsigned**. `6'b110000` reads as **48**, not −16.
- Declaring `logic signed [5:0]` makes two's-complement arithmetic work — the
  same bits now mean **−16**, and comparisons like `>= -DZ` behave correctly.
- If the RTL uses signed values, my reference model **must** declare `signed` or
  every comparison is wrong.

### `!=` vs `!==` (use `!==` in checkers)

- `!=` is a *logical* compare — returns X if either side contains X or Z, which
  can silently let a bad value slip through.
- `!==` is a *case* compare — checks all four states exactly (0,1,X,Z).
- **In a checker, always use `!==`.** If the DUT ever outputs an X
  (uninitialized register — a real bug), `!==` catches it; `!=` might not.

### `=` vs `==` (the classic trap)

- `=` is **assignment**. `==` is **comparison**.
- `if (done = 0)` doesn't compare — it *assigns* 0 to `done` and tests that
  (always false). It compiles without error and misbehaves silently. Nasty.
- In an `if`, I almost always want `==`.

### `$display` format strings

- `%b` binary, `%d` signed decimal, `%h` hex.
- Placeholders need values supplied *after* the string, comma-separated:
  `$display("val=%b", my_signal);` — **not** `$display("val=%b my_signal")`.

### Statements end in `;`

- Every line that *does* something ends in a semicolon. Structural keywords
  (`begin`, `end`, `endtask`, `module`, `case` labels) do not.

---

## Part 4 — Reusable patterns

These are the building blocks. Each one is real code from my testbenches.

### Pattern A — the reference-model function

A pure function that computes the expected output from an input, implementing
the *spec* independently. (From `tilt_decoder`.)

```systemverilog
function automatic signed [5:0] expected_tilt(input [4:0] raw);
    logic signed [5:0] ext;
    begin
        ext = { raw[4], raw };                       // sign-extend
        if ( (ext >= -DZ) && (ext <= DZ) ) return 6'sd0;  // deadzone
        else                                return ext;
    end
endfunction
```

Key idea: the function is **one machine, fed one thing at a time**. I call it
per-axis, per-input — I do *not* rebuild multi-input logic inside it.

### Pattern B — the self-checking task

Drives a stimulus, waits for the DUT, compares against the reference model.

```systemverilog
task automatic check(input [14:0] data);
    logic signed [5:0] exp_x, exp_y;
    begin
        acl_data = data;
        @(posedge clk); #1;                 // wait an edge, let output settle
        exp_x = expected_tilt(data[14:10]);
        exp_y = expected_tilt(data[9:5]);
        if ((exp_x !== tilt_x) || (exp_y !== tilt_y))
            $error("MISMATCH: in=%b exp_x=%d act_x=%d", data, exp_x, tilt_x);
        else
            $display("PASS: in=%b", data);
    end
endtask
```

### Pattern C — advance the clock N cycles

The time-advance primitive for stateful modules. (From `game_timer`.)

```systemverilog
task automatic run_cycles(input int n);
    repeat (n) @(posedge clk);
endtask
```

### Pattern D — drive-and-hold

Set an input to a value and hold it N cycles. (From `debounce`.)

```systemverilog
task automatic hold_btn(input logic val, input int n);
    btn_in = val;
    repeat (n) @(posedge clk);
endtask
```

Match arguments to the signature: `hold_btn(1, 250)` = "set btn_in to **1**,
hold **250** cycles."

### Pattern E — the sticky-flag pulse catcher (important)

To catch a signal that's high for **only one cycle**, somewhere in a window I
can't predict exactly: watch continuously and *latch* the first sighting. (From
`debounce`.)

```systemverilog
task automatic catch_pulse(input int n, output logic seen);
    seen = 0;
    repeat (n) begin
        @(posedge clk); #1;
        if (btn_pulse === 1'b1) seen = 1;   // latch, stays 1 even after it drops
    end
endtask
```

This is a fundamental idiom — catching interrupts, error strobes, single-cycle
handshakes. To fully characterize a pulse: prove it fires when it should
(`seen==1`) **and** prove it doesn't when it shouldn't (`seen==0`).

---

## Part 5 — Stimulus strategy

### Directed tests

I hand-pick the corners I *know* are dangerous, because I don't want to *hope*
random happens to hit them. For `tilt_decoder`: most-negative value
(`5'b10000` = −16), the exact deadzone edges (+1, +2, −1, −2), zero,
most-positive (+15).

Two's complement, quick reference:
- All ones = −1 at any width (`11111` = −1).
- Most negative 5-bit = `10000` = −16.
- Most positive 5-bit = `01111` = +15.

### Constrained-random

Fire thousands of vectors to catch the corners I *didn't* think of.

```systemverilog
repeat (1000) check($urandom);   // $urandom = 32-bit random; check takes low bits
```

It's called *constrained*-random because I can *shape* the randomness — e.g.
bias 30% of vectors near a boundary where bugs cluster. Plain uniform random is
the starting point.

### Directed timing tests (for stateful modules)

For timers/counters/FSMs, the expected value is a function of *elapsed cycles*,
not one input. I set up a known scenario and supply the expected value by
**hand-computation**. Example: reset, start, run 250 cycles at 100 ticks/sec →
`seconds` should be `250/100 = 2`.

> Both directed and random only work because a **self-checking reference model**
> computes the expected answer automatically. That trio — directed +
> constrained-random + self-checking scoreboard — is what "production-grade
> testbench" means, versus a shallow linear testbench.

---

## Part 6 — Fault injection (proving the checker works)

**"All PASS" proves nothing until I've proven the testbench can catch a bug.**
A checker with a bug (e.g. comparing a signal to itself) also prints all PASS.

The procedure (negative testing / bug injection):

1. Deliberately break the DUT — a targeted, known fault.
2. Rerun. The scoreboard **must** scream.
3. Confirm the *failure pattern matches the injected fault* (this is the real
   proof).
4. Restore the correct RTL.

Real example (`tilt_decoder`): I changed the sign extension from
`{x_raw[4], x_raw}` to `{1'b0, x_raw}`. Result: **every negative-value vector
failed** (expected −16, got +16) while **positive/zero vectors still passed**.
The failure pattern precisely matched the fault — the broken bit only affects
negatives. That signature is what proves the checker tests the *right thing*.

This is rare in junior portfolios and a strong interview signal.

---

## Part 7 — The parameter-override trick (fast simulation)

Real designs have huge timing constants: `CLK_HZ = 100000000`,
`COUNT_MAX = 2000000`. Simulating those literally means waiting *billions* of
cycles — hours, or never.

The fix: **override the parameter in the testbench** so the count is small.

```systemverilog
game_timer #(.CLK_HZ(100),  .LIMIT_SEC(60)) dut ( ... );   // 100 ticks/sec, not 100M
debounce   #(.COUNT_MAX(200))               dut ( ... );   // 200, not 2,000,000
```

**Why it's valid:** the *logic* is byte-for-byte identical — only the count
threshold shrinks. The counter still counts, rolls over, and commits exactly the
same way. On hardware it runs with the real value for true timing; in sim it runs
small so a human-length simulation exercises the full behavior.

**How small?** Small enough to be fast, large enough to still exercise the real
behavior. `COUNT_MAX = 200` leaves room to stage a bounce that completes
*partway* (e.g. hold 100 of 200). Going too small (e.g. 1 or 5) can change the
shape of the logic and mask bugs — pick a value with headroom.

This is why designers *parameterize* timing constants: so verification can
rescale for testability. Seeing a big constant as a parameter is the designer
leaving me a handle to grab.

Interview line: *"I overrode the clock-divide parameter to make the timer
simulatable in thousands of cycles instead of billions, without altering the
logic."*

---

## Part 7A — Reactive drivers (when the DUT drives *you*)

In the first testbenches I *drove* the inputs directly. But some modules invert
that: the DUT drives out a request (an address, a command) and expects the
testbench to *respond*. Then the testbench has to **model** the thing the DUT
talks to — a memory, a sensor, a slave device. That model is a **reactive
driver** (a lightweight BFM — bus functional model).

Example (`similarity_calc`): the DUT sweeps a grid, driving out an address
(`cell_x`, `cell_y`) every cycle, and expects `canvas_bit`/`target_bit` back for
that cell. My testbench watches the address and responds:

```systemverilog
// reactive driver: models canvas memory + target generator
always @(posedge clk) begin
    target_bit <= (some rule on cell_x/cell_y);   // combinational-ish
    canvas_bit <= (some rule on cell_x/cell_y);   // 1-cycle BRAM latency (see below)
end
```

Two key ideas:

- **It runs continuously.** A reactive driver is an `always @(posedge clk)` block,
  not a one-shot in `initial` — it reacts to whatever the DUT presents, every
  cycle, for the whole sim.
- **Non-blocking `<=` models read latency for free.** In a clocked block, `<=`
  reads the right-hand side *now* but updates the output *next* cycle. So
  `canvas_bit <= f(cell_x)` makes `canvas_bit` reflect the address one cycle
  late — which is exactly what a BRAM does (present address, data valid one clock
  later). The `<=` *is* the latency. This matters: the DUT was *designed*
  expecting that lag, so my model must reproduce it.

**Selecting patterns:** to test more than one scenario with one reactive driver,
use a `test_mode` variable and a `case` inside the always block — each mode drives
a different pattern. One driver, mode-selected, so there's no double-driving
conflict (never drive the same signal from both an `always` block and an
`initial` block).

Interview line: *"I wrote a reactive BFM that responded to the DUT's swept
address and modeled the canvas BRAM's one-cycle read latency using non-blocking
assignment."*

---

## Part 7B — Handshake synchronization (valid / ready / done)

When the DUT takes many cycles to produce a result, don't guess how long — **wait
for its done flag.** Real designs signal completion with a valid/ready/done
handshake, and the testbench synchronizes to it.

```systemverilog
start = 1; @(posedge clk); start = 0;   // kick it off (one-cycle pulse)
@(posedge score_ready);                  // wait for the DUT to say "done"
check_score(expected);                   // now the result is valid
```

- `@(posedge score_ready)` waits for a **fresh rising edge** — better than
  `wait(score_ready==1)` across multiple tests, because `wait` passes instantly
  if the flag is *still high* from the previous run (stale-flag trap). The rising
  edge forces a new completion.
- **`start` is a pulse, not a level** — assert one cycle, deassert. A start that
  stays high can re-trigger the FSM.
- **Never drive a DUT output.** `score_ready` is an output — I *wait* for it, I
  never assign it. (Assigning it would make the test lie about when the result
  is ready.)

This handshake pattern is everywhere in real DV (AXI valid/ready, memory
done-strobes, interrupt lines).

---

## Part 7C — Coverage (how I know I'm *done* verifying)

A checker tells me *what I hit was correct*. **Coverage** tells me *how much of
the design I actually hit*. I need both — correctness on an under-exercised design
is passing tests on untested logic. "Coverage-driven verification" = writing
tests until coverage is closed. It's how real teams decide verification is done.

For an FSM (`game_fsm`) there are two kinds:

- **State coverage** — did I visit every state? (5/5)
- **Transition coverage** — did I take every legal *arrow* between states? (6/6)

**Transition coverage is stricter, and it matters.** You can hit 100% state
coverage while missing arrows. Example: a test going IDLE→DRAWING→CALC→SCORE→
GAMEOVER visits all 5 states but *skips* the SCORE→DRAWING loop-back — that arrow's
logic is never tested, yet state coverage says "5/5, done." FSM bugs live in the
transitions (wrong condition on an arrow, fires on wrong input), so transition
coverage catches what state coverage can't.

Simple, portable way to track it (same idea as a scoreboard — flags I set as I
go):

```systemverilog
logic visited [0:4];           // one flag per state
logic t_idle_draw;             // one flag per legal transition
// ... set visited[state]=1 after each check; set t_*=1 after each transition ...
// at the end, count and report: "5/5 states, 6/6 transitions"; print anything NOT covered
```

Two disciplines learned here:

- **Cover the transition by its REAL trigger.** GAMEOVER→IDLE happens via
  `start_btn` (per the RTL) — if I trigger it with `rst` instead, the FSM still
  reaches IDLE but I've *reset*, not taken the arrow. Marking it covered would be
  a **false coverage claim**. Always exercise a transition with the input that's
  actually supposed to cause it.
- **To cover a conditional branch, drive both conditions.** SCORE branches on
  `shape_count`: loop-back when <4, game-over when ≥4. One pass takes one branch,
  so the test loops through all 4 shapes to hit both.

The professional tool is SystemVerilog **covergroups** with `coverpoint`/`bins`,
including transition bins: `bins a2b = (S_IDLE => S_DRAWING);`. The `=>` syntax
means "this state then that state," and the tool auto-counts transitions. Naming
"covergroups with transition bins" in an interview signals real coverage
methodology; the flag-based version above demonstrates the same concept by hand.

---

## Part 7D — Reactive slave BFM & protocol timing (the SPI master)

The hardest module: verifying an SPI master (`accelerometer_spi_master`) that
talks to an accelerometer over a 4-wire serial protocol (`sclk`, `mosi`, `miso`,
`cs`). This is the reactive driver of Part 7A taken all the way — the testbench
has to **be the slave device**, obeying a real protocol's bit-level timing.

### The idea

There is no accelerometer in simulation, so the testbench *is* one. It watches
the master's `sclk`/`cs`/`mosi` and drives `miso` back with known data — exactly
what a real ADXL362 does. Crucially, the BFM responds to the **visible protocol
signals**, not to the master's internal 93-state machine or counters. It models
the *interface contract*, not the DUT's guts — so it stays valid even if the
master's internals change, and it's the honest interview story.

### SPI mode-0 timing (the keystone)

- **Slave drives MISO on the FALLING edge of sclk.**
- **Master samples MISO on the RISING edge.**
- They're offset half a clock period so the bit is stable before it's read.

Get this backwards and every captured bit is garbage. The rule: *slave drives on
one edge, master samples on the opposite edge.*

### Structure of the BFM

```systemverilog
// 6 DISTINCT known bytes, so a swap/misalignment shows up (never identical!)
logic [47:0] miso_stream = {x_lsb, x_msb, y_lsb, y_msb, z_lsb, z_msb};
logic [5:0]  bit_idx, sclk_fall_cnt;

always @(negedge cs) begin              // new transaction: reset counters
    sclk_fall_cnt <= 0; bit_idx <= 0;
end

always @(negedge sclk) begin            // drive on falling edge (mode 0)
    if (cs == 1'b0) begin
        sclk_fall_cnt <= sclk_fall_cnt + 1;
        if (sclk_fall_cnt >= THRESH) begin      // past command/address phase
            miso    <= miso_stream[47 - bit_idx];   // MSB-first
            bit_idx <= bit_idx + 1;
        end
    end
end
```

Then the check: I know the bytes I injected, so I compute the expected output
(`acl_data = {X[11:7], Y[11:7], Z[11:7]}`) and compare. Distinct per-axis bytes
mean an axis-swap or a one-bit shift is immediately visible in the result.

### The off-by-one at the command→data boundary (a real lesson)

The read sends 16 command/address bits before the master reads data, so `THRESH`
"should" be 16. It's actually **15**. Why: the master samples the first data bit
on the rising edge right after the 16th bit, and since the slave drives on the
*previous* falling edge, it must present the first bit one edge earlier — at 15.

With `THRESH = 16` the result came out `48b0` instead of `1d03`. The tell:
**the wrong value was my data shifted by one bit, not random garbage.** "My data,
rotated" is the fingerprint of a *sample-alignment* error, not a data error. I
tuned the threshold to 15 and confirmed on the waveform (the first data bit
appears at count 15, stable for the master's first sample).

The transferable principle: **when two clocked processes hand data across a clock
(slave driving vs. master sampling), the exact edge alignment is where
off-by-ones live.** Reason out the approximate boundary from the protocol, then
tune the exact edge empirically against the waveform. Normal DV work, not a
mistake — and "recognizing a shifted-not-garbage result as a timing bug" is a
strong thing to say out loud.

### Note on run time

This module has hardcoded real-world waits (power-up ~24k cycles, the post-config
WAIT ~160k cycles) with no parameter to shrink — so the sim runs hundreds of
thousands of cycles. Use `run all` with the runtime limit cleared and be patient;
a long-running sim isn't a hang.

---

## Part 8 — Waveform debugging

When a text log doesn't explain a failure, **stop guessing and look at the
waveform.** It shows every signal at every moment — it ends theorizing.

How I use it:
1. Add the relevant signals (top-level *and* internal DUT signals — e.g.
   `running`, `cnt` from inside `dut`, added via the Scope panel).
2. Navigate to the failure time (from the `$error` timestamp).
3. Trace the signal that's wrong *backwards* — what drove it to that value?

Real example (`game_timer`): `seconds` read 60 instead of 0. The waveform showed
`seconds` stuck at `3c` (hex 60) even after my reset pulse — the reset wasn't
clearing it. That pointed straight at cross-test contamination (see Part 9),
which no amount of staring at the text log had revealed.

Reading hex in the waveform: `3c` = 60, `c8` = 200, `0a` = 10. (Values show in
the Radix I set — hex or decimal.)

---

## Part 9 — The bugs I keep hitting (personal debug playbook)

These are *my* recurring mistakes. Check this list first when something's wrong.

### 1. Wrong module name in the DUT instance
Copy-pasted a template and left the previous module's name. Fails to elaborate
with confusing errors. **Fix the module name first, always.**

### 2. Cross-test state contamination *(the big one)*
Test N leaves the DUT in some state; Test N+1 assumes a clean slate and fails.
- `game_timer`: TEST 2 left `seconds=60`; TEST 3's narrow reset didn't clear it.
- `debounce`: TEST 1 left `btn_clean=1`; TEST 2's 50-cycle low baseline wasn't
  long enough to un-commit it back to 0.

**Fix:** every test establishes its own clean starting state, and I *verify the
precondition* before testing the thing I care about:

```systemverilog
hold_btn(0, 250);      // return to known baseline
check_clean(0);        // PROVE it's clean before the real test
// ... now the actual test ...
```

A test that passes for the wrong reason (e.g. both control signals were actually
off) is as dangerous as one that fails. Always confirm the stimulus creates the
condition I claim to test.

### 3. Simulation runtime cutoff
Vivado's default "Run Behavioral Simulation" stops at **1000 ns**. Longer tests
(e.g. 250 cycles = 2500 ns) get cut off — *no PASS output prints* because the
sim ended before the check.
- **Fix A:** type `run all` in the Tcl Console (runs to `$finish`).
- **Fix B:** Settings → Simulation → clear `xsim.simulate.runtime` (blank = run
  to `$finish`). Preferred.

### 4. Wrong simulation top module
Vivado simulates **one** top module at a time. With several testbenches +
`top_module` in the project, it may point at the wrong one — I see the wrong
signals and no PASS output. **Fix:** right-click the correct `_tb` in Sim
Sources → **Set as Top**, then rerun. (Or Settings → Simulation top module name.)

### 5. `=` instead of `==`
Compiles silently, always false. See Part 3.

### 6. Missing semicolons / broken `$display` format
See Part 3.

### 7. Pipeline / synchronizer latency
A signal takes N cycles to propagate (e.g. `debounce`'s two-flop synchronizer =
2 cycles before the counter even starts). Hold stimulus *longer* than the raw
count to clear the latency. If a check is off-by-one, suspect latency and look
at the waveform.

### 8. Stimulus race on the clock edge *(subtle — cost me an hour)*
Driving an input *on the same instant* as `@(posedge clk)` races with the DUT's
sampling — the DUT may read the *old* value, so the pulse is missed and nothing
transitions (`game_fsm` was stuck in IDLE). The waveform showed the pulse falling
*between* clock edges, never high at a posedge.
**Fix:** drive inputs a hair *after* the edge so they're stable before the next
sampling edge:
```systemverilog
@(posedge clk); #1; sig = 1;   // set just after the edge
@(posedge clk); #1; sig = 0;
```
Best packaged as a `pulse(sig)` task and reused everywhere.

### 9. `simulate.log` file lock ("cannot access the file...")
A leftover `xsim`/`xelab` process holds the log open, so Vivado can't start a
fresh run. **Fix:** Task Manager → end `xsim.exe`/`xelab.exe`, or delete
`...\behav\xsim\simulate.log`, or reboot. Restarting Vivado alone doesn't always
release it (the process lives outside Vivado). Not a code bug.

---

## Part 10 — The Vivado + Git workflow

### Running a simulation
1. Testbench file must be **`.sv`** and **Set as Top** in Sim Sources.
2. SIMULATION → Run Simulation → **Run Behavioral Simulation**.
3. In the **Tcl Console**: `run all` (runs to `$finish`).
4. Read the **Tcl Console** for PASS/MISMATCH text (the log is where I live; the
   waveform is for zooming into *why*).
5. To rerun after edits: **save the file first** (Vivado runs the saved file),
   then `restart` + `run all`, or relaunch.

Triage the Messages panel: most warnings are project noise (board parts, IP
dirs). The one that matters is the syntax/elaboration error on *my* file.

### The per-module Git ritual
One commit per finished module. Clean history tells a story of steady work.

```bash
cd ~/air-trace-dv
# copy the new _tb.sv into tb/, the PASS log into sim/, notes into docs/
git add .
git commit -m "Add <module> verification: <short description of what was done>"
git push
```

Setup only happens once (already done): `git init`, `git remote add origin ...`,
`git branch -M main`, first `git push -u origin main`.

Repo layout:
```
air-trace-dv/
├── README.md          <- front page; the honesty statement lives here
├── rtl/               <- the design (academic group project — credited)
├── tb/                <- my testbenches
├── docs/              <- notes, bug log, this handbook
└── sim/               <- simulation logs
```

`.gitignore` keeps Vivado build junk out (`*.jou`, `*.log`, `.Xil/`, `*.cache/`,
`*.runs/`, `*.sim/`, `*.gen/`, `xsim.dir/`).

---

## Part 11 — How to verify a NEW module (the ritual)

For every new module, before writing any code, answer four questions in my own
words:

1. **What does it do?** Trace a signal from input to output. What transformation
   happens?
2. **What does "correct" mean?** Given an input, how do I compute the right
   answer by hand — so I can build a reference model?
3. **What are the corner cases?** Boundaries (exact limit ± 1), sign bits,
   simultaneous events, unspecified behavior. *This is where the real
   verification value is.*
4. **How could it fail?** Predict at least one bug. Technique: take each thing
   the module does and ask "what if the designer got the boundary slightly
   wrong?"

Then:
5. Design the **test plan** in English (normal case + each corner case).
6. Write the reference model / checker.
7. Write directed tests for known corners, then constrained-random.
8. Run, debug (Part 9 playbook), get to clean PASS.
9. **Fault-inject** to prove the checker catches bugs (Part 6).
10. Write notes + bug log, push (Part 10).

### Bug vs unspecified behavior (framing that matters)
- A **bug** = the design does something the spec says it *shouldn't*.
- An **unspecified behavior** = the spec never said, and the design does
  *something*.

When I find the second kind (e.g. `game_timer`: when `start` and `stop` assert
on the same edge, the RTL resolves *stop-wins* because it's the later
non-blocking assignment — spec never defined it), I don't call it a bug. I say:
*"unspecified by the spec; the RTL resolves it this way; I flagged it for
clarification."* That precision shows judgment — often more valuable than
finding a plain bug.

---

## Part 11A — How to write a bug-log entry

The bug log (`docs/bug_log.md`) is the highest-value artifact in the portfolio —
most junior candidates have *zero* real findings. Each entry is a mini bug report
with four parts. Write it so a teammate (or interviewer) could reproduce and act
on it.

**1. Symptom** — what I observed, with exact numbers. Which test, expected vs
actual. *"MODE_MATCH returned 95, expected 100."* Not "the score was wrong."

**2. Diagnosis** — how I localized it. The evidence trail: which internal signals
were correct, which were off, and the **isolation logic** that narrows it. This is
the part that shows real DV skill. *"target_cnt and drawn_cnt were correct, only
overlap was short by 30; two different-canvas/same-target patterns both lost the
same 30, proving the loss depends on the target boundary, not the canvas."*

**3. Root-cause hypothesis** — the *why*, with mechanism. *"One-cycle canvas_bit
latency misaligns against registered target_d at each target row boundary → one
overlap missed per row → 30 rows = 30 lost."*

**4. Status** — where it stands and the **next step**. Reproduced? Localized? Root
cause confirmed or open? *"Localized; open whether it's a DUT bug or a test-model
artifact. Next step: waveform at one target-row start comparing canvas_bit vs
target_d."* The next-step line makes it actionable rather than a complaint.

Two framing rules:
- **Bug vs unspecified** (see above) — pick the honest word. Over-claiming "bug"
  when the spec never defined the case gets marked down.
- **Localize, don't just report.** "Score is wrong" is a complaint. "Overlap
  undercounts by one cell per target boundary row, canvas-independent" is a
  finding. The isolation work is the value.

Findings worth logging include ones I found in my *own testbench* (the stimulus
race, cross-test contamination) — they show I debug rigorously and don't trust a
green result blindly.

---

## Part 11B — How to write module "how it works" notes

After each module I write `docs/<module>_notes.md` in my own words. The point
isn't documentation for its own sake — **explaining it back is how I find out
whether I actually own it.** If I can't write why a line is there, I don't
understand it yet, and an interviewer will find the gap.

Five prompts, answered in a sentence or two each:

1. **What does this testbench verify?** The module + the *behaviors* tested (not a
   list of signals — behaviors). Name the algorithm if there is one (IoU,
   debounce, etc.).
2. **What new technique did this module need?** The one thing that made it harder
   than the last (reactive driver, coverage, sticky-flag catcher, parameter
   override) — and *how* it works in one line.
3. **How did the tricky part work?** The corner that took thought (covering both
   FSM branches, catching a one-cycle pulse, the BRAM-latency model).
4. **What was the hardest bug, and how did I find it?** The debugging story —
   symptom, how the waveform revealed it, the fix. This is the interview gold.
5. **How did this testbench differ from the others?** (Combinational vs stateful;
   isolated tests vs one continuous walk; hand-computed values vs auto reference
   model.)

Style rules that keep the notes interview-ready:
- **Precise numbers, correct every time.** "shape_count reaches 4," not "loops 3
  times." A wrong number in the notes is a wrong answer waiting to happen.
- **Name techniques with the real vocabulary** — "constrained-random,"
  "self-checking scoreboard," "reactive BFM," "transition coverage,"
  "directed timing tests." These are the words interviewers listen for.
- **Say it, don't hedge.** If I proved it, "I confirmed X," not "this may show X."
- **Point to the bug log, don't duplicate it.** Notes describe the testbench; the
  bug log holds the finding. One line + a pointer, not the whole symptom twice.
- **My words, not copied.** A polished paragraph I can't defend is worthless; a
  rough one I own is priceless. (I get it reviewed, then it's mine.)

---

## Part 12 — The portfolio framing (for interviews)

The RTL was a collaborative academic project, partly AI-assisted. That is **not**
a weakness to hide — it's the opening. A DV engineer's entire job is verifying
RTL they didn't write. So:

- The **design** is a collaborative academic project (stated plainly).
- The **verification** — testbenches, checkers, coverage, assertions, bug hunt —
  is *mine*, done independently, and I can defend every line.

That last clause is the whole game. In an interview, I must be able to explain
*why* every part of a checker is there. That's why I write the "how it works"
notes in my own words after each module — explaining it back is how I find out
whether I truly own it.

Depth beats breadth: a handful of modules verified *properly* (reference model,
self-checking, coverage, fault injection, real findings) beats sixteen shallow
linear testbenches. I verify the modules that each exercise a *distinct*
technique — datapath, control FSM, timing, scoreboard, coverage, protocol — and
honestly note that display/glue logic was smoke-tested on hardware. That triage
is itself a senior signal.

---

## Quick reference card

| Need | Use |
|---|---|
| Wait one edge | `@(posedge clk);` |
| Wait N edges | `repeat (n) @(posedge clk);` |
| Set + hold input | `hold_btn(val, n);` |
| Compare (catches X) | `if (a !== b) $error(...);` |
| Catch 1-cycle pulse | sticky flag + loop (Pattern E) |
| Random stimulus | `repeat(1000) check($urandom);` |
| Fast sim | override big param: `#(.COUNT_MAX(200))` |
| Respond to DUT's request | reactive driver: `always @(posedge clk)` (Part 7A) |
| Model memory read latency | non-blocking `<=` in a clocked block (Part 7A) |
| Wait for DUT "done" | `@(posedge score_ready);` (Part 7B) |
| One-cycle start | `start=1; @(posedge clk); start=0;` |
| Track coverage | flags per state / per transition (Part 7C) |
| Avoid edge race | drive input `#1` after `@(posedge clk)` |
| Run to end | `run all` (Tcl Console) |
| See internal signals | add from Scope panel to waveform |
| Fix "no output" | wrong sim top, or runtime cutoff |
| Fix stale state | clean baseline + verify precondition |
| Fix file-lock error | Task Manager → end `xsim.exe` |

---

*Built from the Air-Trace DV project — all six target modules verified:
`tilt_decoder`, `game_timer`, `debounce`, `similarity_calc`, `game_fsm`,
`accelerometer_spi_master`. Covers reference models, self-checking scoreboards,
directed + constrained-random stimulus, fault injection, parameter override,
reactive drivers, handshake sync, state + transition coverage, and a
protocol-obeying SPI slave BFM — plus how to write the bug log and module notes.
The next project (a pipelined RISC-V core) is where these habits carry forward.*