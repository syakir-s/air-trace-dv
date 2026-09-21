`timescale 1ns/1ps

module debounce_tb;

  localparam COUNT_MAX = 200;   // small for fast sim (real value 2,000,000)

  logic clk;
  logic btn_in;      
  logic btn_clean;   
  logic btn_pulse;   
  logic pulse_seen;

  debounce #(.COUNT_MAX(COUNT_MAX)) dut (
    .clk(clk),
    .btn_in(btn_in),
    .btn_clean(btn_clean),
    .btn_pulse(btn_pulse)
  );

  // clock
  always #5 clk = ~clk;

  // hold btn_in at a given value for n cycles
  task automatic hold_btn(input logic val, input int n);
      btn_in = val;
      repeat (n) @(posedge clk);
  endtask

  // check btn_clean against expected
  task automatic check_clean(input logic expected);
      #1;
      if (btn_clean !== expected)
          $error("MISMATCH: btn_clean=%b expected=%b", btn_clean, expected);
      else
          $display("PASS: btn_clean=%b", btn_clean);
  endtask
  
    // watch btn_pulse over n cycles; return 1 if it EVER went high
  task automatic catch_pulse(input int n, output logic seen);
      seen = 0;                          // start: haven't seen it
      repeat (n) begin
          @(posedge clk);
          #1;
          if (btn_pulse === 1'b1) seen = 1;   // latch it the instant it's high
      end
  endtask

  initial begin
    // init
    clk = 0; btn_in = 0;

    //  TEST 1: clean press 
    hold_btn(1, 250);
    check_clean(1);
    
    //  TEST 2: bounce ignored 
    // First, fully return to a clean low baseline (undo TEST 1's committed high)
    hold_btn(0, 250);      // hold low long enough for btn_clean to commit back to 0
    check_clean(0);        // PRECONDITION: confirm clean slate before the bounce test

    // Now the bounce: high for only 100 cycles (< COUNT_MAX=200), then drop
    hold_btn(1, 100);
    hold_btn(0, 50);
    check_clean(0);        // debouncer must have IGNORED the bounce -> still 0
    
    //  TEST 3: pulse fires on press, and clean release 
    // clean baseline
    hold_btn(0, 250);
    check_clean(0);

    // press and watch for the pulse across the commit window (~250 cycles)
    btn_in = 1;
    catch_pulse(250, pulse_seen);       // drive high AND watch pulse over the window
    if (pulse_seen)
        $display("PASS: btn_pulse fired on press");
    else
        $error("FAIL: btn_pulse never fired on press");
    check_clean(1);                     // and btn_clean committed

    // clean release: hold low past COUNT_MAX, btn_clean returns to 0
    hold_btn(0, 250);
    check_clean(0);
    
     //  TEST 4: pulse is press-only (no pulse on release) 
    // establish a committed press first
    btn_in = 1;
    catch_pulse(250, pulse_seen);       // (consumes the press pulse)
    check_clean(1);

    // now release and watch - pulse must NOT fire on 1->0
    btn_in = 0;
    catch_pulse(250, pulse_seen);       // watch across the release commit window
    if (pulse_seen == 0)
        $display("PASS: no pulse on release (press-only confirmed)");
    else
        $error("FAIL: btn_pulse fired on release (should be press-only)");
    check_clean(0);                     // and btn_clean returned to 0
    
    $display("Tests done.");
    $finish;
  end

endmodule
