`timescale 1ns/1ps

module game_timer_tb;

  localparam CLK_HZ    = 100;   // small for fast sim - must match DUT override
  localparam LIMIT_SEC = 60;    // must match DUT's LIMIT_SEC

  logic       clk, rst;
  logic       start_timer, stop_timer, reset_timer;
  logic [7:0] seconds;          // 8-bit to match DUT output; not initialized (DUT drives it)
  logic       timer_done;

  // DUT
  game_timer #(.CLK_HZ(CLK_HZ), .LIMIT_SEC(LIMIT_SEC)) dut (
    .clk(clk), .rst(rst),
    .start_timer(start_timer), .stop_timer(stop_timer), .reset_timer(reset_timer),
    .seconds(seconds),
    .timer_done(timer_done)
  );

  // clock
  always #5 clk = ~clk;

  // advance the clock a given number of cycles
  task automatic run_cycles(input int n);
      repeat (n) @(posedge clk);
  endtask

  // check seconds against an expected value
  task automatic check_seconds(input [7:0] expected);
      #1;  // let signals settle after the edge
      if (seconds !== expected)
          $error("MISMATCH: seconds=%d expected=%d", seconds, expected);
      else
          $display("PASS: seconds=%d", seconds);
  endtask
    initial begin
    // init all inputs
    clk = 0; rst = 0;
    start_timer = 0; stop_timer = 0; reset_timer = 0;

    // ---- TEST 1: basic counting ----
    reset_timer = 1;
    @(posedge clk);
    reset_timer = 0;

    start_timer = 1;
    repeat (250) @(posedge clk);

    check_seconds(2);

    // ---- TEST 2: saturation at LIMIT_SEC ----
    reset_timer = 1;
    @(posedge clk);
    reset_timer = 0;

    start_timer = 1;
    repeat (6050) @(posedge clk);   // 60s x 100 ticks = 6000, + margin

    check_seconds(60);              // must clamp at 60, not climb higher

    if (timer_done == 1)
        $display("PASS: timer_done=%b", timer_done);
    else
        $error("FAIL: timer_done=%b", timer_done);

    // ---- TEST 3: start/stop conflict (both asserted same edge) ----
    // Probes an UNSPECIFIED behavior: spec doesn't define what happens
    // when start and stop assert together. RTL resolves stop-wins because
    // `if(stop) running<=0` is the later non-blocking assignment.

    start_timer = 0;
    stop_timer  = 0;
    reset_timer = 1;
    repeat (3) @(posedge clk);
    reset_timer = 0;
    repeat (2) @(posedge clk);
    check_seconds(0);            // precondition: confirmed clean slate

    // Now force the conflict: both high on the same edge
    start_timer = 1;
    stop_timer  = 1;
    @(posedge clk);             // the conflicting edge
    start_timer = 0;
    stop_timer  = 0;

    repeat (300) @(posedge clk);
    check_seconds(0);           // stop-wins => never ran => still 0

    $display("Tests done.");
    $finish;
    $display("Tests done.");
    $finish;
 end 
 endmodule
  