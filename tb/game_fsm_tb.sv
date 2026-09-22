`timescale 1ns/1ps

module game_fsm_tb;

// --- parameters (override big constants for fast sim) ---
localparam S_IDLE = 3'd0, S_DRAWING = 3'd1, S_CALC = 3'd2, S_SCORE = 3'd3, S_GAMEOVER = 3'd4;

// --- signals: match DUT port widths ---
logic clk;              
logic rst;              
logic start_btn;        
logic submit_btn;       
logic next_btn;         
logic score_ready;      
logic [6:0] similarity_score; 
logic timer_done;       
logic draw_enable;      
logic clear_canvas;     
logic start_calc;       
logic show_score;       
logic start_timer;      
logic stop_timer;       
logic reset_timer;      
logic [1:0] target_sel;  
logic [2:0] state;      
logic [7:0] game_score;
// --- transition coverage: one flag per legal arrow ---
logic t_idle_draw;    // IDLE    -> DRAWING
logic t_draw_calc;    // DRAWING -> CALC
logic t_calc_score;   // CALC    -> SCORE
logic t_score_draw;   // SCORE   -> DRAWING (loop-back)
logic t_score_over;   // SCORE   -> GAMEOVER
logic t_over_idle;    // GAMEOVER-> IDLE  

// --- DUT ---
game_fsm dut (
.clk(clk),                
.rst(rst),                
.start_btn(start_btn),          
.submit_btn(submit_btn),         
.next_btn(next_btn),           
.score_ready(score_ready),        
.similarity_score(similarity_score),   
.timer_done(timer_done),         
.draw_enable(draw_enable),        
.clear_canvas(clear_canvas),       
.start_calc(start_calc),         
.show_score(show_score),         
.start_timer(start_timer),        
.stop_timer(stop_timer),         
.reset_timer(reset_timer),        
.target_sel(target_sel),   
.state(state),        
.game_score(game_score) );

  // --- clock ---
  always #5 clk = ~clk;

  // --- reference model / helper tasks ---
  // (see Part 4)

task automatic pulse(ref logic sig);
     @(posedge clk);
     #1;
     sig = 1;
     @(posedge clk);
     #1;
     sig = 0;
endtask

  // --- checker ---
task automatic check_state(input [2:0] expected);
    #1;                 // wait an edge, let output settle
    if (expected !== state)
        $error("MISMATCH: expected_state =%d actual_state =%d", expected, state);
    else
        $display("PASS: state =%d", state);
endtask

// --- coverage tracking ---
logic visited [0:4];              // one flag per state (S_IDLE..S_GAMEOVER)
integer i;

// call this every time you're in a known state, to mark it covered
task automatic cover_state(input [2:0] s);
    visited[s] = 1'b1;
endtask

// at the end, report coverage
task automatic report_coverage();
    integer hit;
    hit = 0;
    for (i = 0; i <= 4; i = i + 1) begin
        if (visited[i]) 
            hit = hit + 1;
        else 
            $display("  NOT COVERED: state %0d", i);
    end
    $display("STATE COVERAGE: %0d/5 states visited", hit);
endtask

task automatic report_transitions();
    integer hit;
    hit = 0;
    if (t_idle_draw)  hit++; else $display("  NOT COVERED: IDLE->DRAWING");
    if (t_draw_calc)  hit++; else $display("  NOT COVERED: DRAWING->CALC");
    if (t_calc_score) hit++; else $display("  NOT COVERED: CALC->SCORE");
    if (t_score_draw) hit++; else $display("  NOT COVERED: SCORE->DRAWING");
    if (t_score_over) hit++; else $display("  NOT COVERED: SCORE->GAMEOVER");
    if (t_over_idle)  hit++; else $display("  NOT COVERED: GAMEOVER->IDLE");
    $display("TRANSITION COVERAGE: %0d/6 transitions taken", hit);
endtask
  
// --- stimulus ---
initial begin
clk = 0;
rst = 0;
start_btn = 0;
submit_btn = 0;
next_btn = 0;
score_ready = 0;
similarity_score = 0;  // ADD THIS INPUT from similarity_calc
timer_done = 0;
t_idle_draw = 0; 
t_draw_calc = 0; 
t_calc_score = 0;
t_score_draw = 0; 
t_score_over = 0; 
t_over_idle = 0;

for (i = 0; i <= 4; i = i + 1)
visited[i] = 0;

// reset to IDLE
pulse(rst);
check_state(S_IDLE);
cover_state(state);
 
// IDLE to DRAWING high on start_btn  
pulse(start_btn);
check_state(S_DRAWING);
cover_state(state);
t_idle_draw = 1;
 
// DRAWING to CALC high on submit_btn 
pulse(submit_btn);
check_state(S_CALC);
cover_state(state);
t_draw_calc = 1;

// CALC to SCORE high on score_ready
pulse(score_ready);
check_state(S_SCORE);
cover_state(state);
t_calc_score = 1;

// SCORE to DRAWING (next_btn, shape_count < 4) 
pulse(next_btn);
check_state(S_DRAWING);
cover_state(state);
t_score_draw = 1; 

//SCORE to GAMEOVER
//repeat until target_sel = 3 last next_btn high (during target_sel ==3) shift FSM to state 4 (S_GAMEOVER) 

repeat (3) begin
    pulse(start_btn);
    pulse(submit_btn);
    pulse(score_ready);
    pulse(next_btn);
end

check_state(S_GAMEOVER);
cover_state(state);
t_score_over = 1;
report_coverage();

//GAMEOVER to IDLE
pulse(start_btn);
check_state(S_IDLE);
cover_state(state);
t_over_idle = 1;
report_transitions();

// ... tests ...
$display("Tests done.");
$finish;
end

endmodule