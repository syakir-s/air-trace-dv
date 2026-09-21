`timescale 1ns / 1ps

module similarity_calc_tb;

// --- parameters (override big constants for fast sim) ---
localparam GRID_W = 80;
localparam GRID_H = 60;
localparam MODE_ZEROS = 3'd0;   // all cells 0
localparam MODE_ONES  = 3'd1;   // all cells 1
localparam MODE_LEFT  = 3'd2;   // canvas = left half, target = all
localparam MODE_SCRIBBLE = 3'd3;
localparam MODE_MATCH = 3'd4;

// --- signals: match DUT port widths ---
logic       clk;
logic       rst;
logic       start;        // start_calc pulse from game_fsm
logic [9:0] cell_x;       // sweep address -> canvas + target_generator
logic [9:0] cell_y;
logic       canvas_bit;   // drawn?    valid 1 clk after cell address (BRAM)
logic       target_bit;   // on target? combinational from cell address
logic [6:0] score;        // 0..100 similarity %
logic       score_ready;
logic [2:0] test_mode;

// --- DUT ---
similarity_calc #(.GRID_W(GRID_W), .GRID_H(GRID_H)) dut (
  .clk(clk),
  .rst(rst),
  .start(start),
  .cell_x(cell_x),
  .cell_y(cell_y),
  .canvas_bit(canvas_bit),
  .target_bit(target_bit),
  .score(score),
  .score_ready(score_ready)
);

// --- clock ---
always #5 clk = ~clk;

// --- reference model / helper tasks ---
// reactive driver: models canvas memory (1-cycle latency) + target generator
always @(posedge clk) begin
    case (test_mode)
        MODE_ZEROS: begin
            canvas_bit <= 1'b0;
            target_bit <= 1'b0;
        end
        MODE_ONES: begin
            canvas_bit <= 1'b1;
            target_bit <= 1'b1;
        end
        MODE_LEFT: begin
            canvas_bit <= (cell_x < 40) ? 1'b1 : 1'b0 ;
            target_bit <= 1'b1;
        end
        MODE_SCRIBBLE: begin 
            canvas_bit <= (cell_x < 40) ? 1'b1 : 1'b0;
            target_bit <= (cell_y < 30 & cell_x < 40) ? 1'b1 : 1'b0;
        end
        MODE_MATCH: begin
        // canvas AND target identical: both on for a box in the corner
            canvas_bit <= (cell_x < 40 & cell_y < 30) ? 1'b1 : 1'b0;
            target_bit <= (cell_x < 40 & cell_y < 30) ? 1'b1 : 1'b0;
        end

        default: begin
            canvas_bit <= 1'b0;
            target_bit <= 1'b0;
        end
        
    endcase
end

// --- checker ---
task automatic check_score(input [6:0] expected);
    #1;
    if (score !== expected)
        $error("MISMATCH: got=%d expected=%d", score, expected);
    else
        $display("PASS: out=%d", score);
endtask

// --- stimulus ---
initial begin
clk = 0; 
rst = 1; 
start = 0;
target_bit = 0; 
canvas_bit = 0;

// TEST 1

test_mode = MODE_ZEROS;
rst = 1;  @(posedge clk);
rst = 0;  @(posedge clk);

start = 1; @(posedge clk); 
start = 0; @(posedge clk);

@(posedge score_ready);

check_score(0);

//TEST 2

test_mode = MODE_ONES;
rst = 1;  @(posedge clk);
rst = 0;  @(posedge clk);   

start = 1; @(posedge clk); 
start = 0; @(posedge clk); 

@(posedge score_ready);

check_score(100); 

//TEST 3 

test_mode = MODE_LEFT;
rst = 1;  @(posedge clk);
rst = 0;  @(posedge clk);   

start = 1; @(posedge clk); 
start = 0; @(posedge clk); 

@(posedge score_ready);

check_score(50); 
$display("[%0t] TEST 3 (LEFT) done: score=%d", $time, score);


//TEST 4 
test_mode = MODE_SCRIBBLE;
rst = 1;  @(posedge clk);
rst = 0;  @(posedge clk);   

start = 1; @(posedge clk); 
start = 0; @(posedge clk); 

@(posedge score_ready);

check_score(50); 
$display("[%0t] TEST 4 (SCRIBBLE) done: score=%d", $time, score);

//TEST 5 
test_mode = MODE_MATCH;
rst = 1;  @(posedge clk);
rst = 0;  @(posedge clk);   

start = 1; @(posedge clk); 
start = 0; @(posedge clk); 

@(posedge score_ready);

check_score(100); 

$display("Tests done.");
$finish;
end
endmodule
