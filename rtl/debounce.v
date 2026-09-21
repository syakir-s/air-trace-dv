module debounce #(
parameter integer COUNT_MAX = 2000000   // ~20 ms at 100 MHz
)
(
input  wire clk,
input  wire btn_in,
output reg btn_clean = 1'b0,
output reg btn_pulse = 1'b0
);
reg s0 = 1'b0, s1 = 1'b0;
always @(posedge clk) 
begin
    s0 <= btn_in;
    s1 <= s0;
end
reg [$clog2(COUNT_MAX+1)-1:0] cnt = 0;
always @(posedge clk)
begin
    btn_pulse <= 1'b0;
    if (s1 != btn_clean) 
begin
    cnt <= cnt + 1'b1;
    if (cnt == COUNT_MAX) 
begin
    btn_clean <= s1;
    cnt       <= 0;
    if (s1) btn_pulse <= 1'b1;
end
end else 
begin
    cnt <= 0;
end
end
endmodule
