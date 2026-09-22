module game_fsm(
input wire clk,
input wire rst,
input wire start_btn,
input wire submit_btn,
input wire next_btn,
input wire score_ready,
input wire [6:0] similarity_score,  // ADD THIS INPUT from similarity_calc
input wire timer_done, 
output reg draw_enable,
output reg clear_canvas,
output reg start_calc,
output reg show_score,
output reg start_timer,       // Start timer
output reg stop_timer,        // Stop timer
output reg reset_timer, 
output reg[1:0] target_sel,
output wire[2:0] state, 
output reg [7:0] game_score
);

localparam 
S_IDLE = 3'd0,
S_DRAWING = 3'd1,
S_CALC = 3'd2,
S_SCORE = 3'd3,
S_GAMEOVER = 3'd4;  // ADDED: game over state

reg[2:0] state_reg = S_IDLE;
reg [9:0] total_score = 10'd0;     // Accumulates scores for all shapes
reg [2:0] shape_count = 3'd0;     // Counts how many shapes completed
//reg calc_done = 1'b0;             // Flag for calculation completion

assign state = state_reg;

always@(posedge clk) begin
if(rst) begin
    state_reg    <= S_IDLE;
    target_sel   <= 2'd0;
    draw_enable  <= 1'b0;
    clear_canvas <= 1'b0;
    start_calc   <= 1'b0;
    show_score   <= 1'b0;
    game_score   <= 8'd0;
    total_score  <= 8'd0;
    shape_count  <= 2'd0;
    //calc_done    <= 1'b0;
end else begin
    // Default outputs
    draw_enable  <= 1'b0;
    clear_canvas <= 1'b0;
    start_calc   <= 1'b0;
    show_score   <= 1'b0;
    start_timer <= 1'b0;
    stop_timer <= 1'b0;
    reset_timer <= 1'b0;
    
    case(state_reg)
    
    S_IDLE: begin   
        game_score <= 8'd0;
        total_score <= 8'd0;
        shape_count <= 2'd0;
        target_sel <= 2'd0;
        reset_timer <= 1'b1;
        if (start_btn) begin   
            clear_canvas <= 1'b1;
            state_reg <= S_DRAWING;
        end
    end
                
    S_DRAWING: begin 
        draw_enable <= 1'b1;
        start_timer <= 1'b1;
        
         if (timer_done) begin
            start_calc <= 1'b1;
            stop_timer <= 1'b1;
            state_reg <= S_CALC;
         end
        // Allow drawing with pen
        // Submit button triggers calculation
        if(submit_btn) begin 
            start_calc <= 1'b1;
            stop_timer <= 1'b1;
            state_reg <= S_CALC;
        end
    end
                
    S_CALC: begin 
        // Wait for similarity calculation to complete
        if (score_ready) begin
            // Store the score (similarity_score is 0-100)
            total_score <= total_score + similarity_score;
            shape_count <= shape_count + 1'b1;
            state_reg <= S_SCORE;
        end
    end
                
    S_SCORE: begin  
        show_score <= 1'b1;
        reset_timer <= 1'b1; 
        if(next_btn) begin  
            // Check if all 4 shapes are completed
            if (shape_count >= 3'd4) begin  // 0,1,2,3 = 4 shapes
                // Calculate final average score
                game_score <= total_score / 4;
                state_reg <= S_GAMEOVER;
            end else begin
                // Move to next shape
                target_sel <= target_sel + 1'b1;
                clear_canvas <= 1'b1;
                
                state_reg <= S_DRAWING;
            end
        end
    end
    
    S_GAMEOVER: begin
        // Display final score
        show_score <= 1'b1;
        stop_timer <= 1'b1;
        // Press start to go back to menu
        if (start_btn) begin
            state_reg <= S_IDLE;
        end
    end

    default: state_reg <= S_IDLE;
    
    endcase
end
end

endmodule