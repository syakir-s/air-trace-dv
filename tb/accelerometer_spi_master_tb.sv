`timescale 1ns/1ps

module accelerometer_spi_master_tb;

localparam [6:0]    POWER_UP    = 7'h00,
                    //SPI WRITE
                    BEGIN_SPIW = 7'h01,
                    //send write instruction 0x0A
                    SEND_WCMD7  = 7'h02,
                    SEND_WCMD6  = 7'h03,
                    SEND_WCMD5  = 7'h04,
                    SEND_WCMD4  = 7'h05,
                    SEND_WCMD3  = 7'h06,
                    SEND_WCMD2  = 7'h07,
                    SEND_WCMD1  = 7'h08,
                    SEND_WCMD0  = 7'h09,
                    // send register addess to write to 0x2D
                    SEND_WADDR7 = 7'h0A,
                    SEND_WADDR6 = 7'h0B,
                    SEND_WADDR5 = 7'h0C,
                    SEND_WADDR4 = 7'h0D,
                    SEND_WADDR3 = 7'h0E,
                    SEND_WADDR2 = 7'h0F,
                    SEND_WADDR1 = 7'h10,
                    SEND_WADDR0 = 7'h11,
                    //send byte to put into measurement mode 0x02
                    SEND_BYTE7  = 7'h12,
                    SEND_BYTE6  = 7'h13,
                    SEND_BYTE5  = 7'h14,
                    SEND_BYTE4  = 7'h15,
                    SEND_BYTE3  = 7'h16,
                    SEND_BYTE2  = 7'h17,
                    SEND_BYTE1  = 7'h18,
                    SEND_BYTE0  = 7'h19,
                    //wait for first valid date after init measurement mode = 40ms
                    WAIT = 7'h1A,
                    //spi read
                    BEGIN_SPIR  = 7'h1B,
                    //send read instructio 0x0B
                    SEND_RCMD7  = 7'h1C,
                    SEND_RCMD6  = 7'h1D,
                    SEND_RCMD5  = 7'h1E,
                    SEND_RCMD4  = 7'h1F,
                    SEND_RCMD3  = 7'h20,
                    SEND_RCMD2  = 7'h21,  
                    SEND_RCMD1  = 7'h22,
                    SEND_RCMD0  = 7'h23,
                    //send X data LSB register address 0x0E
                    SEND_RADDR7 = 7'h24,
                    SEND_RADDR6 = 7'h25,
                    SEND_RADDR5 = 7'h26,
                    SEND_RADDR4 = 7'h27,
                    SEND_RADDR3 = 7'h28,
                    SEND_RADDR2 = 7'h29,
                    SEND_RADDR1 = 7'h2A,
                    SEND_RADDR0 = 7'h2B,
                    //receive X data LSB fron 0x0E
                    REC_XLSB7   = 7'h2C,
                    REC_XLSB6   = 7'h2D,
                    REC_XLSB5   = 7'h2E,
                    REC_XLSB4   = 7'h2F,
                    REC_XLSB3   = 7'h30,
                    REC_XLSB2   = 7'h31,
                    REC_XLSB1   = 7'h32,
                    REC_XLSB0   = 7'h33,  
                    //receive X data MSB from 0x0F
                    REC_XMSB7   = 7'h34,
                    REC_XMSB6   = 7'h35,  
                    REC_XMSB5   = 7'h36,   
                    REC_XMSB4   = 7'h37,   
                    REC_XMSB3   = 7'h38,   
                    REC_XMSB2   = 7'h39,   
                    REC_XMSB1   = 7'h3A,   
                    REC_XMSB0   = 7'h3B,  
                    //receive Y data LSB fron 0x0E 
                    REC_YLSB7   = 7'h3C,
                    REC_YLSB6   = 7'h3D,
                    REC_YLSB5   = 7'h3E,
                    REC_YLSB4   = 7'h3F,
                    REC_YLSB3   = 7'h40,
                    REC_YLSB2   = 7'h41,
                    REC_YLSB1   = 7'h42,
                    REC_YLSB0   = 7'h43,
                    //receive Y data MSB from 0x0F
                    REC_YMSB7   = 7'h44,
                    REC_YMSB6   = 7'h45,  
                    REC_YMSB5   = 7'h46,   
                    REC_YMSB4   = 7'h47,   
                    REC_YMSB3   = 7'h48,   
                    REC_YMSB2   = 7'h49,   
                    REC_YMSB1   = 7'h4A,   
                    REC_YMSB0   = 7'h4B, 
                    //receive Z data LSB fron 0x0E 
                    REC_ZLSB7   = 7'h4C,
                    REC_ZLSB6   = 7'h4D,
                    REC_ZLSB5   = 7'h4E,
                    REC_ZLSB4   = 7'h4F,
                    REC_ZLSB3   = 7'h50,
                    REC_ZLSB2   = 7'h51,
                    REC_ZLSB1   = 7'h52,
                    REC_ZLSB0   = 7'h53,
                    //receive Z data MSB from 0x0F
                    REC_ZMSB7   = 7'h54,
                    REC_ZMSB6   = 7'h55,  
                    REC_ZMSB5   = 7'h56,   
                    REC_ZMSB4   = 7'h57,   
                    REC_ZMSB3   = 7'h58,   
                    REC_ZMSB2   = 7'h59,   
                    REC_ZMSB1   = 7'h5A,   
                    REC_ZMSB0   = 7'h5B, 
                    //end SPI commmunications 
                    END_SPI     = 7'h5C;    //wait 10ms, CS = 0, SCLK = idle = 0, loop back to BEGIN_SPIW

// --- signals: match DUT port widths ---
logic iclk;
logic miso;
logic sclk;
logic mosi;
logic cs;
logic [14:0] acl_data;
// --- Slave BFM: models the ADXL362 accelerometer ---
// 6 DISTINCT known bytes the "sensor" returns (so swaps/misalignment show up)
logic [7:0] x_lsb = 8'hA5;
logic [7:0] x_msb = 8'h13;   // X = {x_msb, x_lsb} = 16'h13A5
logic [7:0] y_lsb = 8'h5A;
logic [7:0] y_msb = 8'h24;   // Y = 16'h245A
logic [7:0] z_lsb = 8'hF0;
logic [7:0] z_msb = 8'h31;   // Z = 16'h31F0

// pack all 48 bits in the order the master reads them: X_LSB, X_MSB, Y_LSB, Y_MSB, Z_LSB, Z_MSB
logic [47:0] miso_stream;
logic [5:0]  bit_idx;        // which bit we're sending (0..47)
logic [5:0]  sclk_fall_cnt;  // count falling edges since cs went low

// expected acl_data, computed from the bytes we fed
logic [15:0] exp_X, exp_Y, exp_Z;
logic [14:0] exp_acl;
// --- DUT ---
accelerometer_spi_master dut (
    .iclk(iclk),
    .miso(miso),
    .sclk(sclk),
    .mosi(mosi),
    .cs(cs),
    .acl_data(acl_data)
);

// --- clock ---
always 
#5
iclk = ~iclk;

// assemble the 48-bit stream: X_LSB first (sent MSB-first), then X_MSB, Y_LSB...
// order matches the master's read sequence
initial miso_stream = {x_lsb, x_msb, y_lsb, y_msb, z_lsb, z_msb};

// start a fresh transaction each time cs goes low
always @(negedge cs) begin
    sclk_fall_cnt <= 0;
    bit_idx       <= 0;
end

// drive MISO on each falling edge of sclk (SPI mode 0: slave drives on negedge)
always @(negedge sclk) begin
    if (cs == 1'b0) begin
        sclk_fall_cnt <= sclk_fall_cnt + 1;

        // first 16 sclk periods = read-command(8) + register-address(8) on MOSI
        // after that, the master reads data -> we drive it
        if (sclk_fall_cnt >= 15) begin
            miso    <= miso_stream[47 - bit_idx];   // MSB-first
            bit_idx <= bit_idx + 1;
        end
    end
end

initial begin
    exp_X = {x_msb, x_lsb};   // 16'h13A5
    exp_Y = {y_msb, y_lsb};   // 16'h245A
    exp_Z = {z_msb, z_lsb};   // 16'h31F0
    exp_acl = {exp_X[11:7], exp_Y[11:7], exp_Z[11:7]};
end

// --- stimulus + check ---
initial begin
    iclk = 0;
    miso = 0;

    #2000000;   // crude: wait 2ms of sim time for the first read to complete
    
    if (acl_data !== exp_acl)
        $error("MISMATCH: acl_data=%h expected=%h", acl_data, exp_acl);
    else
        $display("PASS: acl_data=%h", acl_data);

    $finish;
    end
endmodule