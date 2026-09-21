module similarity_calc #(
parameter integer GRID_W = 160,
parameter integer GRID_H = 120
)
(
input  wire        clk,
input  wire        rst,
input  wire        start,        // start_calc pulse from game_fsm
output reg  [9:0]  cell_x,       // sweep address -> canvas + target_generator
output reg  [9:0]  cell_y,
input  wire        canvas_bit,   // drawn?    valid 1 clk after cell address (BRAM)
input  wire        target_bit,   // on target? combinational from cell address
output reg  [6:0]  score,        // 0..100 similarity %
output reg         score_ready   // 1 when score is valid
);
localparam integer CELLS = GRID_W * GRID_H;
localparam S_IDLE = 2'd0, S_SWEEP = 2'd1, S_DONE = 2'd2;

reg [1:0]  state = S_IDLE;
reg [16:0] present_cnt;          // cells whose address we have presented (0..CELLS)
reg        acc_en;               // accumulate the previous cell this cycle
reg        target_d;             // target_bit registered to align with canvas latency
reg [16:0] overlap, target_cnt, drawn_cnt;

wire [17:0] union_w = target_cnt + drawn_cnt - overlap;

always @(posedge clk) begin
if (rst) begin
    state<=S_IDLE; score<=0; score_ready<=0;
    cell_x<=0; cell_y<=0; present_cnt<=0; acc_en<=0; target_d<=0;
    overlap<=0; target_cnt<=0; drawn_cnt<=0;
end else begin
case (state)
S_IDLE: begin
    score_ready <= 0;
    if (start) begin
        overlap<=0; target_cnt<=0; drawn_cnt<=0; score<=0;
        cell_x<=0; cell_y<=0; present_cnt<=0; acc_en<=0; target_d<=0;
        state<=S_SWEEP;
    end
end
S_SWEEP: 
begin
// accumulate the cell presented last cycle (its bits are valid now)
if (acc_en) begin
    if (canvas_bit & target_d) overlap    <= overlap + 1'b1;
    if (target_d)              target_cnt <= target_cnt + 1'b1;
    if (canvas_bit)            drawn_cnt  <= drawn_cnt + 1'b1;
end
if (present_cnt < CELLS) begin
target_d    <= target_bit;        // latch target for the current cell
acc_en      <= 1'b1;              // accumulate it next cycle
present_cnt <= present_cnt + 1'b1;
// advance raster scan for the next cell
if (cell_x == GRID_W-1) begin
    cell_x <= 0;
    cell_y <= cell_y + 1'b1;
end else begin
    cell_x <= cell_x + 1'b1;
end
end else begin
    acc_en <= 1'b0;                   // stop; drain the last sample
    if (!acc_en) state <= S_DONE;
end
end
S_DONE: 
begin
    score       <= (union_w == 0) ? 7'd0 : (overlap*100) / union_w;
    score_ready <= 1'b1;
    state       <= S_IDLE;
end
endcase
end
end
endmodule