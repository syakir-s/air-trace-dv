module tilt_decoder #(
    parameter integer DEADZONE = 1  // flat surface
)
(
    input  wire              clk,           
    input  wire [14:0]       acl_data,  // data from SPI master
    output reg  signed [5:0] tilt_x,     // left/right tilt
    output reg  signed [5:0] tilt_y     // up/down  tilt
);

    // extract signed (5 bit) from SPI master 
    wire signed [4:0] x_raw = acl_data[14:10]; 
    wire signed [4:0] y_raw = acl_data[9:5];     
  
 
    // extend each axit form 5 bit into 6 bit 
    wire signed [5:0] x_ext = {x_raw[4], x_raw}; // copy sign bit (bit 4)
    wire signed [5:0] y_ext = {y_raw[4], y_raw};
 
    // flatsurface
    localparam signed [5:0] DZ = DEADZONE;
 
    // apply the deadzone and register the outputs
    always @(posedge clk) begin
        
        if (x_ext <= DZ && x_ext >= -DZ) 
            tilt_x <= 6'sd0; // if (x_ext <= DZ && x_ext >= -DZ) no tilt
        else
            tilt_x <= x_ext;
 
        if (y_ext <= DZ && y_ext >= -DZ) 
            tilt_y <= 6'sd0; // if (y_ext <= DZ && y_ext >= -DZ) no vectored
        else
            tilt_y <= y_ext;
    end
 
endmodule
