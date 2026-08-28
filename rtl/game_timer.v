module game_timer #(
    parameter integer CLK_HZ    = 100000000,
    parameter integer LIMIT_SEC = 60
)(
    input  wire clk, input wire rst,
    input  wire start_timer, input wire stop_timer, input wire reset_timer,
    output reg [7:0] seconds = 8'd0,
    output wire timer_done
);
    reg running = 1'b0;
    reg [31:0] tick = 32'd0;
    always @(posedge clk) begin
        if (rst || reset_timer) begin
            seconds <= 8'd0; 
            tick <= 32'd0; 
            running <= 1'b0;
        end else begin
            if (start_timer) running <= 1'b1;
            if (stop_timer)  running <= 1'b0;
            if (running) begin
                if (tick == CLK_HZ-1) begin
                    tick <= 32'd0;
                    if (seconds < LIMIT_SEC) seconds <= seconds + 1'b1;
                end else tick <= tick + 1'b1;
            end
        end
    end
    assign timer_done = (seconds >= LIMIT_SEC);
endmodule
