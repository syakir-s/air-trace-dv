`timescale 1ns/1ps

module tilt_decoder_tb;

  localparam signed [5:0] DZ = 1;      // must match DUT's DEADZONE

  logic                clk;
  logic  [14:0]        acl_data;
  logic  signed [5:0]  tilt_x, tilt_y;

  // DUT
  tilt_decoder #(.DEADZONE(1)) dut (
    .clk(clk), .acl_data(acl_data),
    .tilt_x(tilt_x), .tilt_y(tilt_y)
  );

  // clock
  always #5 clk = ~clk;

  // reference model (yours)
  function automatic signed [5:0] expected_tilt(input [4:0] raw);
    logic signed [5:0] ext;
    begin
      ext = { raw[4], raw };
      if ( (ext >= -DZ) && (ext <= DZ) ) return 6'sd0;
      else                                return ext;
    end
  endfunction

  // checker (yours)
  task automatic check(input [14:0] data);
    logic signed [5:0] exp_x, exp_y;
    begin
      acl_data = data;
      @(posedge clk); #1;
      exp_x = expected_tilt(data[14:10]);
      exp_y = expected_tilt(data[9:5]);
      if ((exp_x !== tilt_x) || (exp_y !== tilt_y))
        $error("MISMATCH: acl_data=%b exp_x=%d act_x=%d exp_y=%d act_y=%d",
                data, exp_x, tilt_x, exp_y, tilt_y);
      else
        $display("PASS: acl_data=%b tilt_x=%d tilt_y=%d", data, tilt_x, tilt_y);
    end
  endtask

  // stimulus (yours)
  initial begin
    clk = 0; acl_data = 0;
    @(posedge clk);

    check(15'b10000_00000_00000);  // -16
    check(15'b00001_00000_00000);  // +1 -> 0
    check(15'b00010_00000_00000);  // +2
    check(15'b11111_00000_00000);  // -1 -> 0
    check(15'b11110_00000_00000);  // -2
    check(15'b01111_00000_00000);  // +15

    repeat (1000) check($urandom);

    $display("All tests done.");
    $finish;
  end

endmodule