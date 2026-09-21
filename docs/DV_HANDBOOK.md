# Design Verification Handbook

*A practical field guide for verifying RTL, built from the Air-Trace project.*

This handbook is written for future-me. It captures the reasoning, the reusable
patterns, and the Vivado workflow I learned verifying the Air-Trace modules
(`tilt\_decoder`, `game\_timer`, `debounce`), so I can verify the next module
independently. Read it once end-to-end; after that, use it as a reference.

The examples are all real — they come from testbenches I wrote and debugged.

\---

## Part 0 — What verification actually is

Design Verification (DV) is the job of **proving that RTL behaves the way the
spec says it should** — and finding the places where it doesn't. The design
engineer writes the RTL; the DV engineer tries to break it.

The single most important mental model:

> \*\*Two independent things are fed the same stimulus. If they disagree, there's a bug.\*\*

* The **DUT** (Design Under Test) is the RTL — one interpretation of the spec.
* The **reference model** is a second, independent interpretation of the *same
spec*, written by me in the testbench.
* The **checker/scoreboard** compares the two, every cycle or every transaction.

When they disagree, either the DUT is wrong or my model is wrong — and running
that disagreement down *is the job*.

A testbench that only ever prints PASS has proven nothing until I've also proven
it can *fail* (see Part 6, fault injection). "All PASS" and "my checker is
blind" look identical from the outside.

\---

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

\---

## Part 2 — Anatomy of a testbench

Almost every testbench I write — up to full UVM — is this same skeleton with
fancier versions of each block:

```
signals  ->  DUT instance  ->  clock  ->  reference model  ->  checker  ->  stimulus
```

1. **Signals** — one variable per DUT port.
2. **DUT instance** — instantiate the design, with parameter overrides.
3. **Clock generator** — `always #5 clk = \~clk;` (10 ns period).
4. **Reference model** — computes the expected answer, independently.
5. **Checker/scoreboard** — compares expected vs actual, logs mismatches.
6. **Stimulus** — the `initial` block that drives inputs and calls checks.

### The minimal template

```systemverilog
`timescale 1ns/1ps

module my\_module\_tb;

  // --- parameters (override big constants for fast sim) ---
  localparam PARAM = 100;

  // --- signals: match DUT port widths ---
  logic        clk;
  logic \[7:0]  in\_signal;    // driven by TB
  logic \[7:0]  out\_signal;   // read from DUT (no initializer)

  // --- DUT ---
  my\_module #(.PARAM(PARAM)) dut (
    .clk(clk),
    .in\_signal(in\_signal),
    .out\_signal(out\_signal)
  );

  // --- clock ---
  always #5 clk = \~clk;

  // --- reference model / helper tasks ---
  // (see Part 4)

  // --- checker ---
  task automatic check(input \[7:0] expected);
      #1;
      if (out\_signal !== expected)
          $error("MISMATCH: got=%d expected=%d", out\_signal, expected);
      else
          $display("PASS: out=%d", out\_signal);
  endtask

  // --- stimulus ---
  initial begin
    clk = 0; in\_signal = 0;
    // ... tests ...
    $display("Tests done.");
    $finish;
  end

endmodule
```

### Rules baked into the template

* **A signal I only *read* from the DUT** is declared to match the DUT's width
and is **never initialized** by me — the DUT drives it. Only signals *I drive*
get initial values.
* **`clk = 0;`** is the first line of the `initial` block, so the clock starts
from a known value instead of `x`.
* **First thing after copy-pasting a template: fix the module name** in the DUT
instantiation. This is the #1 copy-paste bug (I hit it every single time).

\---

## Part 3 — The language essentials (SystemVerilog for TB)

I do **not** memorize syntax. I look it up, every time, forever — that's the
job. What I keep in my head is *what* to write, not the exact characters. This
table is the vocabulary I actually use.

### `logic` vs `reg`

* Verilog RTL uses `reg` (assigned in a procedural block) and `wire`
(continuous). `reg` does *not* mean a hardware register — it's a naming
accident.
* SystemVerilog testbenches use **`logic`** — the modern replacement. More
flexible (drivable procedurally *or* continuously) and it doesn't lie about
hardware.
* Both are **4-state** (0, 1, X, Z). This matters — see `!==` below.
* File extension decides the language: **RTL in `.v` (Verilog), testbench in
`.sv` (SystemVerilog).** Mixing them in one project is normal and standard.
A `logic` in a `.v` file throws a syntax error — because `.v` is compiled as
old Verilog.

### `signed`

* By default variables are **unsigned**. `6'b110000` reads as **48**, not −16.
* Declaring `logic signed \[5:0]` makes two's-complement arithmetic work — the
same bits now mean **−16**, and comparisons like `>= -DZ` behave correctly.
* If the RTL uses signed values, my reference model **must** declare `signed` or
every comparison is wrong.

### `!=` vs `!==` (use `!==` in checkers)

* `!=` is a *logical* compare — returns X if either side contains X or Z, which
can silently let a bad value slip through.
* `!==` is a *case* compare — checks all four states exactly (0,1,X,Z).
* **In a checker, always use `!==`.** If the DUT ever outputs an X
(uninitialized register — a real bug), `!==` catches it; `!=` might not.

### `=` vs `==` (the classic trap)

* `=` is **assignment**. `==` is **comparison**.
* `if (done = 0)` doesn't compare — it *assigns* 0 to `done` and tests that
(always false). It compiles without error and misbehaves silently. Nasty.
* In an `if`, I almost always want `==`.

### `$display` format strings

* `%b` binary, `%d` signed decimal, `%h` hex.
* Placeholders need values supplied *after* the string, comma-separated:
`$display("val=%b", my\_signal);` — **not** `$display("val=%b my\_signal")`.

### Statements end in `;`

* Every line that *does* something ends in a semicolon. Structural keywords
(`begin`, `end`, `endtask`, `module`, `case` labels) do not.

\---

## Part 4 — Reusable patterns

These are the building blocks. Each one is real code from my testbenches.

### Pattern A — the reference-model function

A pure function that computes the expected output from an input, implementing
the *spec* independently. (From `tilt\_decoder`.)

```systemverilog
function automatic signed \[5:0] expected\_tilt(input \[4:0] raw);
    logic signed \[5:0] ext;
    begin
        ext = { raw\[4], raw };                       // sign-extend
        if ( (ext >= -DZ) \&\& (ext <= DZ) ) return 6'sd0;  // deadzone
        else                                return ext;
    end
endfunction
```

Key idea: the function is **one machine, fed one thing at a time**. I call it
per-axis, per-input — I do *not* rebuild multi-input logic inside it.

### Pattern B — the self-checking task

Drives a stimulus, waits for the DUT, compares against the reference model.

```systemverilog
task automatic check(input \[14:0] data);
    logic signed \[5:0] exp\_x, exp\_y;
    begin
        acl\_data = data;
        @(posedge clk); #1;                 // wait an edge, let output settle
        exp\_x = expected\_tilt(data\[14:10]);
        exp\_y = expected\_tilt(data\[9:5]);
        if ((exp\_x !== tilt\_x) || (exp\_y !== tilt\_y))
            $error("MISMATCH: in=%b exp\_x=%d act\_x=%d", data, exp\_x, tilt\_x);
        else
            $display("PASS: in=%b", data);
    end
endtask
```

### Pattern C — advance the clock N cycles

The time-advance primitive for stateful modules. (From `game\_timer`.)

```systemverilog
task automatic run\_cycles(input int n);
    repeat (n) @(posedge clk);
endtask
```

### Pattern D — drive-and-hold

Set an input to a value and hold it N cycles. (From `debounce`.)

```systemverilog
task automatic hold\_btn(input logic val, input int n);
    btn\_in = val;
    repeat (n) @(posedge clk);
endtask
```

Match arguments to the signature: `hold\_btn(1, 250)` = "set btn\_in to **1**,
hold **250** cycles."

### Pattern E — the sticky-flag pulse catcher (important)

To catch a signal that's high for **only one cycle**, somewhere in a window I
can't predict exactly: watch continuously and *latch* the first sighting. (From
`debounce`.)

```systemverilog
task automatic catch\_pulse(input int n, output logic seen);
    seen = 0;
    repeat (n) begin
        @(posedge clk); #1;
        if (btn\_pulse === 1'b1) seen = 1;   // latch, stays 1 even after it drops
    end
endtask
```

This is a fundamental idiom — catching interrupts, error strobes, single-cycle
handshakes. To fully characterize a pulse: prove it fires when it should
(`seen==1`) **and** prove it doesn't when it shouldn't (`seen==0`).

\---

## Part 5 — Stimulus strategy

### Directed tests

I hand-pick the corners I *know* are dangerous, because I don't want to *hope*
random happens to hit them. For `tilt\_decoder`: most-negative value
(`5'b10000` = −16), the exact deadzone edges (+1, +2, −1, −2), zero,
most-positive (+15).

Two's complement, quick reference:

* All ones = −1 at any width (`11111` = −1).
* Most negative 5-bit = `10000` = −16.
* Most positive 5-bit = `01111` = +15.

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

> Both directed and random only work because a \*\*self-checking reference model\*\*
> computes the expected answer automatically. That trio — directed +
> constrained-random + self-checking scoreboard — is what "production-grade
> testbench" means, versus a shallow linear testbench.

\---

## Part 6 — Fault injection (proving the checker works)

**"All PASS" proves nothing until I've proven the testbench can catch a bug.**
A checker with a bug (e.g. comparing a signal to itself) also prints all PASS.

The procedure (negative testing / bug injection):

1. Deliberately break the DUT — a targeted, known fault.
2. Rerun. The scoreboard **must** scream.
3. Confirm the *failure pattern matches the injected fault* (this is the real
proof).
4. Restore the correct RTL.

Real example (`tilt\_decoder`): I changed the sign extension from
`{x\_raw\[4], x\_raw}` to `{1'b0, x\_raw}`. Result: **every negative-value vector
failed** (expected −16, got +16) while **positive/zero vectors still passed**.
The failure pattern precisely matched the fault — the broken bit only affects
negatives. That signature is what proves the checker tests the *right thing*.

This is rare in junior portfolios and a strong interview signal.

\---

## Part 7 — The parameter-override trick (fast simulation)

Real designs have huge timing constants: `CLK\_HZ = 100000000`,
`COUNT\_MAX = 2000000`. Simulating those literally means waiting *billions* of
cycles — hours, or never.

The fix: **override the parameter in the testbench** so the count is small.

```systemverilog
game\_timer #(.CLK\_HZ(100),  .LIMIT\_SEC(60)) dut ( ... );   // 100 ticks/sec, not 100M
debounce   #(.COUNT\_MAX(200))               dut ( ... );   // 200, not 2,000,000
```

**Why it's valid:** the *logic* is byte-for-byte identical — only the count
threshold shrinks. The counter still counts, rolls over, and commits exactly the
same way. On hardware it runs with the real value for true timing; in sim it runs
small so a human-length simulation exercises the full behavior.

**How small?** Small enough to be fast, large enough to still exercise the real
behavior. `COUNT\_MAX = 200` leaves room to stage a bounce that completes
*partway* (e.g. hold 100 of 200). Going too small (e.g. 1 or 5) can change the
shape of the logic and mask bugs — pick a value with headroom.

This is why designers *parameterize* timing constants: so verification can
rescale for testability. Seeing a big constant as a parameter is the designer
leaving me a handle to grab.

Interview line: *"I overrode the clock-divide parameter to make the timer
simulatable in thousands of cycles instead of billions, without altering the
logic."*

\---

## Part 8 — Waveform debugging

When a text log doesn't explain a failure, **stop guessing and look at the
waveform.** It shows every signal at every moment — it ends theorizing.

How I use it:

1. Add the relevant signals (top-level *and* internal DUT signals — e.g.
`running`, `cnt` from inside `dut`, added via the Scope panel).
2. Navigate to the failure time (from the `$error` timestamp).
3. Trace the signal that's wrong *backwards* — what drove it to that value?

Real example (`game\_timer`): `seconds` read 60 instead of 0. The waveform showed
`seconds` stuck at `3c` (hex 60) even after my reset pulse — the reset wasn't
clearing it. That pointed straight at cross-test contamination (see Part 9),
which no amount of staring at the text log had revealed.

Reading hex in the waveform: `3c` = 60, `c8` = 200, `0a` = 10. (Values show in
the Radix I set — hex or decimal.)

\---

## Part 9 — The bugs I keep hitting (personal debug playbook)

These are *my* recurring mistakes. Check this list first when something's wrong.

### 1\. Wrong module name in the DUT instance

Copy-pasted a template and left the previous module's name. Fails to elaborate
with confusing errors. **Fix the module name first, always.**

### 2\. Cross-test state contamination *(the big one)*

Test N leaves the DUT in some state; Test N+1 assumes a clean slate and fails.

* `game\_timer`: TEST 2 left `seconds=60`; TEST 3's narrow reset didn't clear it.
* `debounce`: TEST 1 left `btn\_clean=1`; TEST 2's 50-cycle low baseline wasn't
long enough to un-commit it back to 0.

**Fix:** every test establishes its own clean starting state, and I *verify the
precondition* before testing the thing I care about:

```systemverilog
hold\_btn(0, 250);      // return to known baseline
check\_clean(0);        // PROVE it's clean before the real test
// ... now the actual test ...
```

A test that passes for the wrong reason (e.g. both control signals were actually
off) is as dangerous as one that fails. Always confirm the stimulus creates the
condition I claim to test.

### 3\. Simulation runtime cutoff

Vivado's default "Run Behavioral Simulation" stops at **1000 ns**. Longer tests
(e.g. 250 cycles = 2500 ns) get cut off — *no PASS output prints* because the
sim ended before the check.

* **Fix A:** type `run all` in the Tcl Console (runs to `$finish`).
* **Fix B:** Settings → Simulation → clear `xsim.simulate.runtime` (blank = run
to `$finish`). Preferred.

### 4\. Wrong simulation top module

Vivado simulates **one** top module at a time. With several testbenches +
`top\_module` in the project, it may point at the wrong one — I see the wrong
signals and no PASS output. **Fix:** right-click the correct `\_tb` in Sim
Sources → **Set as Top**, then rerun. (Or Settings → Simulation top module name.)

### 5\. `=` instead of `==`

Compiles silently, always false. See Part 3.

### 6\. Missing semicolons / broken `$display` format

See Part 3.

### 7\. Pipeline / synchronizer latency

A signal takes N cycles to propagate (e.g. `debounce`'s two-flop synchronizer =
2 cycles before the counter even starts). Hold stimulus *longer* than the raw
count to clear the latency. If a check is off-by-one, suspect latency and look
at the waveform.

\---

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
cd \~/air-trace-dv
# copy the new \_tb.sv into tb/, the PASS log into sim/, notes into docs/
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

`.gitignore` keeps Vivado build junk out (`\*.jou`, `\*.log`, `.Xil/`, `\*.cache/`,
`\*.runs/`, `\*.sim/`, `\*.gen/`, `xsim.dir/`).

\---

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

* A **bug** = the design does something the spec says it *shouldn't*.
* An **unspecified behavior** = the spec never said, and the design does
*something*.

When I find the second kind (e.g. `game\_timer`: when `start` and `stop` assert
on the same edge, the RTL resolves *stop-wins* because it's the later
non-blocking assignment — spec never defined it), I don't call it a bug. I say:
*"unspecified by the spec; the RTL resolves it this way; I flagged it for
clarification."* That precision shows judgment — often more valuable than
finding a plain bug.

\---

## Part 12 — The portfolio framing (for interviews)

The RTL was a collaborative academic project, partly AI-assisted. That is **not**
a weakness to hide — it's the opening. A DV engineer's entire job is verifying
RTL they didn't write. So:

* The **design** is a collaborative academic project (stated plainly).
* The **verification** — testbenches, checkers, coverage, assertions, bug hunt —
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

\---

## Quick reference card

|Need|Use|
|-|-|
|Wait one edge|`@(posedge clk);`|
|Wait N edges|`repeat (n) @(posedge clk);`|
|Set + hold input|`hold\_btn(val, n);`|
|Compare (catches X)|`if (a !== b) $error(...);`|
|Catch 1-cycle pulse|sticky flag + loop (Pattern E)|
|Random stimulus|`repeat(1000) check($urandom);`|
|Fast sim|override big param: `#(.COUNT\_MAX(200))`|
|Run to end|`run all` (Tcl Console)|
|See internal signals|add from Scope panel to waveform|
|Fix "no output"|wrong sim top, or runtime cutoff|
|Fix stale state|clean baseline + verify precondition|

\---

*Built from the Air-Trace DV project: `tilt\_decoder`, `game\_timer`, `debounce`.
Extend it as I verify `similarity\_calc`, `game\_fsm`, and the SPI master.*

