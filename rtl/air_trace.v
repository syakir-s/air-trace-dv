`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/26/2026 10:38:13 AM
// Design Name: 
// Module Name: air_trace
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module accelerometer_spi_master(
    input iclk,
    input miso,
    output sclk,
    output reg mosi = 1'b0,
    output reg cs = 1'b1,
    output [14:0] acl_data
    );
    //cntrl sclk output for spi mode 
    reg sclk_control = 1'b0;
    
    reg clk_counter = 1'b0;
    reg clk_reg = 1'b1;
    
    always@(posedge iclk) 
    begin
        clk_counter <= clk_counter + 1;
        if(clk_counter == 1'b1)
            clk_reg <= ~clk_reg;
    end
    
    reg [7:0] write_instr   = 8'h0A;
    reg [7:0] mode_reg_addr = 8'h2D;
    reg [7:0] mode_wr_data  = 8'h02;
    reg [7:0] read_instr    = 8'h0B;
    reg [7:0] x_LSB_addr    = 8'h0E;
    reg [14:0] temp_DATA    = 15'b0;
    reg [15:0] X;
    reg [15:0] Y;
    reg [15:0] Z;
    reg [31:0] counter = 32'b0;
    wire latch_data;
    
    //93 states for state machine
    localparam [6:0] POWER_UP    = 7'h00,
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
    //state register 
    reg [6:0] state_reg = POWER_UP;
    
    always @(posedge iclk) 
    begin   
        counter <= counter +  1;    //increment statemachine sync counter
        case(state_reg)
            POWER_UP    :
            begin
                if(counter == 32'd23999)    //wait for 6ms, for sensor to reach standby mode
                    state_reg <= BEGIN_SPIW;
            end
    //begin SPI write command to initiate a write sequence
            BEGIN_SPIW  : 
            begin
                if(counter == 32'd24001)
                    begin 
                    state_reg <= SEND_WCMD7;
                    cs <= 1'b0;
                    end
            end
    //send the write command to initiate a write sequence
    SEND_WCMD7  :
    begin
        sclk_control <= 1'b1;
        mosi <= write_instr[7];
        if(counter == 32'd24005)
            state_reg <= SEND_WCMD6;
    end 
    SEND_WCMD6  :
    begin
        mosi <= write_instr[6];
        if(counter == 32'd24009)
            state_reg <= SEND_WCMD5;
        end
    SEND_WCMD5  :
    begin
        mosi <= write_instr[5];
        if(counter == 32'd24013)
            state_reg <= SEND_WCMD4;
        end
    SEND_WCMD4  :
    begin
        mosi <= write_instr[4];
        if(counter == 32'd24017)
            state_reg <= SEND_WCMD3;
        end
    SEND_WCMD3  :
    begin
        mosi <= write_instr[3];
        if(counter == 32'd24021)
            state_reg <= SEND_WCMD2;
        end
    SEND_WCMD2  :
    begin
        mosi <= write_instr[2];
        if(counter == 32'd24025)
            state_reg <= SEND_WCMD1;
    end
    SEND_WCMD1  :
    begin
        mosi <= write_instr[1];
        if(counter == 32'd24029)
            state_reg <= SEND_WCMD0;
    end
    SEND_WCMD0  :
    begin
        mosi <= write_instr[0];
        if(counter == 32'd24033)
            state_reg <= SEND_WADDR7;
    end
    //send address to write to, in this case the 0x2D register, to configure sensor to measurement mode
    SEND_WADDR7  :
    begin
        mosi <= mode_reg_addr[7];
        if(counter == 32'd24037)
            state_reg <= SEND_WADDR6;
    end
    SEND_WADDR6  :
    begin
        mosi <= mode_reg_addr[6];
        if(counter == 32'd24041)
            state_reg <= SEND_WADDR5;
    end
    SEND_WADDR5  :
    begin
        mosi <= mode_reg_addr[5];
        if(counter == 32'd24045)
            state_reg <= SEND_WADDR4;
    end
    SEND_WADDR4  :
    begin
        mosi <= mode_reg_addr[4];
        if(counter == 32'd24049)
            state_reg <= SEND_WADDR3;
    end
    SEND_WADDR3  :
    begin
        mosi <= mode_reg_addr[3];
        if(counter == 32'd24053)
            state_reg <= SEND_WADDR2;
    end
    SEND_WADDR2  :
    begin
        mosi <= mode_reg_addr[2];
        if(counter == 32'd24057)
            state_reg <= SEND_WADDR1;
    end
    SEND_WADDR1  :
    begin
        mosi <= mode_reg_addr[1];
        if(counter == 32'd24061)
            state_reg <= SEND_WADDR0;
    end
    SEND_WADDR0  :
    begin
        mosi <= mode_reg_addr[0];
        if(counter == 32'd24065)
            state_reg <= SEND_BYTE7;
    end
    //send value to write to the 0x2D register, ijn this case 0x02, for measurement mode 
    SEND_BYTE7  :
    begin
        mosi <= mode_wr_data[7];
        if(counter == 32'd24069)
            state_reg <= SEND_BYTE6;
    end
    SEND_BYTE6  :
    begin
        mosi <= mode_wr_data[6];
        if(counter == 32'd24073)
            state_reg <= SEND_BYTE5;
    end
    SEND_BYTE5  :
    begin
        mosi <= mode_wr_data[5];
        if(counter == 32'd24077)
            state_reg <= SEND_BYTE4;
    end
    SEND_BYTE4  :
    begin
        mosi <= mode_wr_data[4];
        if(counter == 32'd24081)
            state_reg <= SEND_BYTE3;
    end
    SEND_BYTE3  :
    begin
        mosi <= mode_wr_data[3];
        if(counter == 32'd24085)
            state_reg <= SEND_BYTE2;
    end
    SEND_BYTE2  :
    begin
        mosi <= mode_wr_data[2];
        if(counter == 32'd24089)
            state_reg <= SEND_BYTE1;
    end
    SEND_BYTE1  :
    begin
        mosi <= mode_wr_data[1];
        if(counter == 32'd24093)
            state_reg <= SEND_BYTE0;
    end
    SEND_BYTE0  :
    begin
        mosi <= mode_wr_data[0];
        if(counter == 32'd24097) 
        begin
            state_reg <= WAIT;
            counter <= 32'd0;
            cs <= 1'b1;
            sclk_control <= 1'b0;
        end
    end
    //eait for 40ms after setting measurement mode to allow the first valis=d data, 160000 ticks+ 3 to line up SCLK
    WAIT    :
    begin
        if(counter == 32'd160002)
        begin
            counter <= 32'd0;
            state_reg <= BEGIN_SPIR;
        end
    end
    //begin SPI read communication with sensor by sending CS low 
    BEGIN_SPIR  :
    begin
        if(counter == 32'd1)
        begin 
            state_reg <= SEND_RCMD7;
            cs <= 1'b0;
            sclk_control <= 1'b1;
        end 
    end
    //send the read command to initiate a read sequence 
    SEND_RCMD7  :
    begin
        mosi <= read_instr[7];
        if(counter == 32'd4)
            state_reg <= SEND_RCMD6;
        end
        SEND_RCMD6  :
    begin
        mosi <= read_instr[6];
        if(counter == 32'd8)
            state_reg <= SEND_RCMD5;
        end
        SEND_RCMD5  :
    begin
        mosi <= read_instr[5];
        if(counter == 32'd12)
            state_reg <= SEND_RCMD4;
        end
        SEND_RCMD4  :
    begin
        mosi <= read_instr[4];
        if(counter == 32'd16)
            state_reg <= SEND_RCMD3;
        end
        SEND_RCMD3  :
    begin
        mosi <= read_instr[3];
        if(counter == 32'd20)
            state_reg <= SEND_RCMD2;
        end
        SEND_RCMD2  :
    begin
        mosi <= read_instr[2];
        if(counter == 32'd24)
            state_reg <= SEND_RCMD1;
        end
        SEND_RCMD1  :
    begin
        mosi <= read_instr[1];
        if(counter == 32'd28)
            state_reg <= SEND_RCMD0;
        end
        SEND_RCMD0  :
    begin
        mosi <= read_instr[0];
        if(counter == 32'd32)
            state_reg <= SEND_RADDR7;
        end
//send register address to read from, in this case 0x0E, the x data LSB
    SEND_RADDR7 :
        begin 
            mosi <= x_LSB_addr[7];
            if(counter == 32'd36)
                state_reg <= SEND_RADDR6;
        end
     SEND_RADDR6 :
        begin 
            mosi <= x_LSB_addr[6];
            if(counter == 32'd40)
                state_reg <= SEND_RADDR5;
        end
     SEND_RADDR5 :
        begin 
            mosi <= x_LSB_addr[5];
            if(counter == 32'd44)
                state_reg <= SEND_RADDR4;
        end
    SEND_RADDR4 :
        begin 
            mosi <= x_LSB_addr[4];
            if(counter == 32'd48)
                state_reg <= SEND_RADDR3;
        end
    SEND_RADDR3 :
        begin 
            mosi <= x_LSB_addr[3];
            if(counter == 32'd52)
                state_reg <= SEND_RADDR2;
        end
    SEND_RADDR2 :
        begin 
            mosi <= x_LSB_addr[2];
            if(counter == 32'd56)
                state_reg <= SEND_RADDR1;
        end
    SEND_RADDR1 :
        begin 
            mosi <= x_LSB_addr[1];
            if(counter == 32'd60)
                state_reg <= SEND_RADDR0;
        end
    SEND_RADDR0 :
        begin 
            mosi <= x_LSB_addr[0];
            if(counter == 32'd64)
                state_reg <= REC_XLSB7;
        end
//receive x data LSB[7:0], store in LSB of X data reg
    REC_XLSB7    :
        begin
            X[7] <= miso;
            if(counter == 32'd68)
                state_reg <= REC_XLSB6;
        end
    REC_XLSB6    :
        begin
            X[6] <= miso;
            if(counter == 32'd72)
                state_reg <= REC_XLSB5;
        end 
    REC_XLSB5    :
        begin
            X[5] <= miso;
            if(counter == 32'd76)
                state_reg <= REC_XLSB4;
        end
    REC_XLSB4    :
        begin
            X[4] <= miso;
            if(counter == 32'd80)
                state_reg <= REC_XLSB3;
        end
    REC_XLSB3    :
        begin
            X[3] <= miso;
            if(counter == 32'd84)
                state_reg <= REC_XLSB2;
        end
    REC_XLSB2    :
        begin
            X[2] <= miso;
            if(counter == 32'd88)
                state_reg <= REC_XLSB1;
        end
    REC_XLSB1    :
        begin
            X[1] <= miso;
            if(counter == 32'd92)
                state_reg <= REC_XLSB0;
        end
   REC_XLSB0    :
        begin
            X[0] <= miso;
            if(counter == 32'd96)
                state_reg <= REC_XMSB7;
        end
//receive x data MSB[7:0], store in MSB of X data reg
    REC_XMSB7   :
        begin
            X[15] <= miso;
            if(counter == 32'd100)
                state_reg<= REC_XMSB6;
        end
    REC_XMSB6   :
        begin
            X[14] <= miso;
            if(counter == 32'd104)
                state_reg<= REC_XMSB5;
        end
    REC_XMSB5   :
        begin
            X[13] <= miso;
            if(counter == 32'd108)
                state_reg <= REC_XMSB4;
        end
   REC_XMSB4   :
        begin
            X[12] <= miso;
            if(counter == 32'd112)
                state_reg <= REC_XMSB3;
        end
   REC_XMSB3   :
        begin
            X[11] <= miso;
            if(counter == 32'd116)
                state_reg <= REC_XMSB2;
        end
   REC_XMSB2   :
        begin
            X[10] <= miso;
            if(counter == 32'd120)
                state_reg <= REC_XMSB1;
        end
   REC_XMSB1   :
        begin
            X[9] <= miso;
            if(counter == 32'd124)
                state_reg <= REC_XMSB0;
        end
   REC_XMSB0    :
        begin 
            X[8] <= miso;
            if(counter == 32'd128)
                state_reg <= REC_YLSB7;
        end
//receive y data LSB[7:0], store in LSB of Y data reg        
    REC_YLSB7   :
        begin
            Y[7] <= miso;
            if(counter == 32'd132)
                state_reg <= REC_YLSB6;
        end
   REC_YLSB6   :
        begin
            Y[6] <= miso;
            if(counter == 32'd136)
                state_reg <= REC_YLSB5;
        end
   REC_YLSB5   :
        begin
            Y[5] <= miso;
            if(counter == 32'd140)
                state_reg <= REC_YLSB4;
        end
   REC_YLSB4   :
        begin
            Y[4] <= miso;
            if(counter == 32'd144)
                state_reg <= REC_YLSB3;
        end
    REC_YLSB3   :
        begin
            Y[3] <= miso;
            if(counter == 32'd148)
                state_reg <= REC_YLSB2;
        end
    REC_YLSB2   :
        begin
            Y[2] <= miso;
            if(counter == 32'd152)
                state_reg <= REC_YLSB1;
        end
    REC_YLSB1   :
        begin
            Y[1] <= miso;
            if(counter == 32'd156)
                state_reg <= REC_YLSB0;
        end
    REC_YLSB0   :
        begin
            Y[0] <= miso;
            if(counter == 32'd160)
                state_reg <= REC_YMSB7;
        end
//receive Y data MSB[7:0], store in MSB of Y data reg
    REC_YMSB7   :
        begin
            Y[15] <= miso;
            if(counter == 32'd164)
                state_reg <= REC_YMSB6;
        end
    REC_YMSB6   :
        begin
            Y[14] <= miso;
            if(counter == 32'd168)
                state_reg <= REC_YMSB5;
        end
    REC_YMSB5   :
        begin
            Y[13] <= miso;
            if(counter == 32'd172)
                state_reg <= REC_YMSB4;
        end
    REC_YMSB4   :
        begin
            Y[12] <= miso;
            if(counter == 32'd176)
                state_reg <= REC_YMSB3;
        end
    REC_YMSB3   :
        begin
            Y[11] <= miso;
            if(counter == 32'd180)
                state_reg <= REC_YMSB2;
        end
    REC_YMSB2   :
        begin
            Y[10] <= miso;
            if(counter == 32'd184)
                state_reg <= REC_YMSB1;
        end
    REC_YMSB1   :
        begin
            Y[9] <= miso;
            if(counter == 32'd188)
                state_reg <= REC_YMSB0;
        end
    REC_YMSB0   :
        begin
            Y[8] <= miso;
            if(counter == 32'd192)
                state_reg <= REC_ZLSB7;
        end
//receive Z data LSB[7:0], store in LSB of Z data reg
    REC_ZLSB7   :
        begin
            Z[7] <= miso;
            if(counter == 32'd196)
                state_reg <= REC_ZLSB6;
        end
    REC_ZLSB6   :
        begin
            Z[6] <= miso;
            if(counter == 32'd200)
                state_reg <= REC_ZLSB5;
        end
    REC_ZLSB5   :
        begin
            Z[5] <= miso;
            if(counter == 32'd204)
                state_reg <= REC_ZLSB4;
        end
    REC_ZLSB4   :
        begin
            Z[4] <= miso;
            if(counter == 32'd208)
                state_reg <= REC_ZLSB3;
        end
    REC_ZLSB3   :
        begin
            Z[3] <= miso;
            if(counter == 32'd212)
                state_reg <= REC_ZLSB2;
        end
    REC_ZLSB2   :
        begin
            Z[2] <= miso;
            if(counter == 32'd216)
                state_reg <= REC_ZLSB1;
        end
    REC_ZLSB1   :
        begin
            Z[1] <= miso;
            if(counter == 32'd220)
                state_reg <= REC_ZLSB0;
        end
    REC_ZLSB0   :
        begin
            Z[0] <= miso;
            if(counter == 32'd224)
                state_reg <= REC_ZMSB7;
        end
//receive Y data MSB[7:0], store in MSB of Y data reg
    REC_ZMSB7   :
        begin
            Z[15] <= miso;
            if(counter == 32'd228)
                state_reg <= REC_ZMSB6;
        end
    REC_ZMSB6   :
        begin
            Z[14] <= miso;
            if(counter == 32'd232)
                state_reg <= REC_ZMSB5;
        end
    REC_ZMSB5   :
        begin
            Z[13] <= miso;
            if(counter == 32'd236)
                state_reg <= REC_ZMSB4;
        end
    REC_ZMSB4   :
        begin
            Z[12] <= miso;
            if(counter == 32'd240)
                state_reg <= REC_ZMSB3;
        end
    REC_ZMSB3   :
        begin
            Z[11] <= miso;
            if(counter == 32'd244)
                state_reg <= REC_ZMSB2;
        end
    REC_ZMSB2   :
        begin
            Z[10] <= miso;
            if(counter == 32'd248)
                state_reg <= REC_ZMSB1;
        end
    REC_ZMSB1   :
        begin
            Z[9] <= miso;
            if(counter == 32'd252)
                state_reg <= REC_ZMSB0;
        end
    REC_ZMSB0   :
        begin
            Z[8] <= miso;
            if(counter == 32'd256)
            begin
                cs <= 1'b1;
                sclk_control <= 1'b0; 
                state_reg <= END_SPI;
            end
        end
//end read communications, wait 10 =ms for 100Hz data rate = 40000 ticks
    END_SPI :
        begin 
            if(counter == 32'd40259)
            begin
                counter <= 32'd0;
                state_reg <= BEGIN_SPIR;
            end
        end 
    endcase
end
//data buffer 
always @(negedge iclk)
    if(latch_data)
    begin   
        temp_DATA <= { X[11:7], Y[11:7], Z[11:7] };
    end
//output acclerometer data 
assign acl_data = temp_DATA;

assign latch_data = ((state_reg == END_SPI) && (counter == 32'd258)) ? 1:0;
assign sclk = (sclk_control) ? clk_reg : 0;

endmodule

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

module cursor_controller #(
parameter integer SCREEN_W = 640, // screen width  in pixels
parameter integer SCREEN_H = 480, // screen height in pixels
parameter integer MOVE_DIV = 1000000 // clocks between cursor updates
)
(
input wire clk, // system clock
input wire rst, // reset centre the 
input wire signed [5:0] tilt_x,        
input wire signed [5:0] tilt_y,         
input wire pen_btn,        
output reg [10:0] cursor_x,       
output reg [9:0] cursor_y,        
output wire pen_down // 1 while drawing
);

assign pen_down = pen_btn; // button 
//1. generate a slow "move tick" so the cursor isn't too fast
reg [31:0] tick_cnt   = 32'd0;
reg move_tick  = 1'b0;

always @(posedge clk) begin
if (tick_cnt == MOVE_DIV - 1) 
begin
    tick_cnt  <= 32'd0;
    move_tick <= 1'b1; // pulse high for one clock
    end
else 
begin
    tick_cnt  <= tick_cnt + 1'b1;
    move_tick <= 1'b0;
    end
end
//2. work out the next position (signed, so it can go below 0)
    wire signed [11:0] next_x = $signed({2'b00, cursor_x}) + tilt_x;
    wire signed [11:0] next_y = $signed({2'b00, cursor_y}) + tilt_y;
 
//3. update the cursor on each tick, clamped to the screen 
always @(posedge clk) 
begin
if (rst) 
begin
    cursor_x <= SCREEN_W / 2;        // start in the centre
    cursor_y <= SCREEN_H / 2;
end 
else 
if (move_tick) 
begin
// --- X axis ---
if (next_x < 0)
    cursor_x <= 10'd0;                  // hit left edge
else 
if (next_x > SCREEN_W - 1)
    cursor_x <= SCREEN_W - 1;           // hit right edge
else
cursor_x <= next_x[10:0];            // normal move
 
            // --- Y axis ---
if (next_y < 0)
    cursor_y <= 10'd0;                  // hit top edge
else 
if (next_y > SCREEN_H - 1)
    cursor_y <= SCREEN_H - 1;           // hit bottom edge
else
cursor_y <= next_y[9:0];            // normal move
end
end
 
endmodule

module canvas_memory #(
parameter integer GRID_W     = 160,  // cells across (640 >> CELL_SHIFT)
parameter integer GRID_H     = 120,  // cells down   (480 >> CELL_SHIFT)
parameter integer CELL_SHIFT = 2     // cell = 2^CELL_SHIFT px (here 4x4)
)
(
input wire clk,
//write side (drawing) 
input  wire draw_enable, // from game_fsm (1 only in DRAWING state)
input  wire pen_down, // pen pressed (1 = drawing)
input  wire [10:0] cursor_x, // cursor position (full screen res)
input  wire [9:0] cursor_y,
input  wire clear_canvas, // 1-cycle pulse: wipe the whole canvas

//read side (display)
input  wire [10:0] pixel_x, // screen pixel the VGA is drawing now
input  wire [9:0] pixel_y,
output reg pixel_on // 1 if that pixel's cell is inked
);
localparam integer CELLS = GRID_W * GRID_H;
localparam integer AW = $clog2(CELLS); // address width
 
// one bit per cell. Block RAM.
reg canvas [0:CELLS-1];
 
//clear sweep: walk every address and write 0
reg clearing = 1'b0;
reg [AW-1:0] clear_addr = 0;
always @(posedge clk) 
begin
if (clear_canvas) 
begin
    clearing   <= 1'b1;       // start wiping
    clear_addr <= 0;
end 
else if (clearing) 
begin
if (clear_addr == CELLS-1)
    clearing <= 1'b0;      // reached the last cell -> done
    clear_addr <= clear_addr + 1'b1;
end
end

//map the cursor position to a grid cell, then an address
wire [9:0] wcol = cursor_x >> CELL_SHIFT;   // column = x / 4
wire [9:0] wrow = cursor_y >> CELL_SHIFT;   // row    = y / 4
wire [AW-1:0] waddr = wrow * GRID_W + wcol;
 
// write port: clear takes priority, otherwise ink the cell 
always @(posedge clk) 
begin
if (clearing)
    canvas[clear_addr] <= 1'b0;             // wiping
else if (draw_enable && pen_down)
    canvas[waddr] <= 1'b1;                  // drawing
end

//map the current screen pixel to a cell, then an address
wire [9:0]    rcol  = pixel_x >> CELL_SHIFT;
wire [9:0]    rrow  = pixel_y >> CELL_SHIFT;
wire [AW-1:0] raddr = rrow * GRID_W + rcol;
 
//read port: synchronous (BRAM has 1-cycle read latency)
always @(posedge clk) 
begin
pixel_on <= canvas[raddr];
end
 
endmodule

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

module target_generator #(
parameter integer GRID_W = 160,   
parameter integer GRID_H = 120,   
parameter integer HALF   = 80,    
parameter integer THICK  = 6     
)
(
input  wire [1:0] target_sel,     
input  wire [9:0] cell_x,         
input  wire [9:0] cell_y,         
output reg target_on       
);

localparam integer CX = GRID_W / 2;   
localparam integer CY = GRID_H / 2;   

wire [9:0] dx = (cell_x >= CX) ? (cell_x - CX) : (CX - cell_x);
wire [9:0] dy = (cell_y >= CY) ? (cell_y - CY) : (CY - cell_y);

wire [10:0] maxd   = (dx > dy) ? dx : dy;   // Chebyshev  -> square
wire [10:0] sumd   = dx + dy;               // Manhattan  -> diamond
wire [19:0] distsq = dx*dx + dy*dy;         // Euclidean^2-> circle

localparam integer RIN   = HALF - THICK;    // 38
localparam integer ROUT  = HALF + THICK;    // 42
localparam integer RIN2  = RIN  * RIN;      // 1444
localparam integer ROUT2 = ROUT * ROUT;     // 1764

always @(*) 
begin
case (target_sel)
// square outline: Chebyshev distance sits in the band
2'd0: 
target_on = (maxd >= RIN) && (maxd <= ROUT);

// diamond outline: Manhattan distance sits in the band
2'd1:
target_on = (sumd >= RIN) && (sumd <= ROUT);

// plus/cross: a thin vertical or horizontal bar, kept inside a HALF-sized square region
2'd2: 
target_on = ((dx <= THICK) || (dy <= THICK)) && (maxd <= HALF);

// circle outline: squared distance sits in the band
2'd3: 
target_on = (distsq >= RIN2) && (distsq <= ROUT2);

default: target_on = 1'b0;
endcase
end

endmodule

module canvas_renderer #(
    parameter integer LIMIT_SEC = 60
)(
    input wire clk,
    input wire video_on,
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire pixel_on,
    input wire target_on,
    input wire [9:0] cursor_x,
    input wire [9:0] cursor_y,
    input wire [6:0] score,
    input wire show_score,
    input wire [7:0] seconds,
    input wire bar_on,
    input wire [2:0] state,        // NEW: to know menu / gameover
    input wire [7:0] game_score,   // NEW: final averaged score for end screen
    output reg [3:0] vga_r,
    output reg [3:0] vga_g,
    output reg [3:0] vga_b
);
    localparam integer CUR=2, BW=8;
    localparam integer BAR_TOP=16, BAR_BOT=28, BAR_LEFT=20, BAR_FULL_W=600;
    localparam S_IDLE=3'd0, S_GAMEOVER=3'd4;

    wire is_menu     = (state == S_IDLE);
    wire is_gameover = (state == S_GAMEOVER);

    // ---- border / cursor / bar (as before) ----
    wire border_hit = (pixel_x<BW)||(pixel_x>=640-BW)||(pixel_y<BW)||(pixel_y>=480-BW);
    wire [9:0] adx = (pixel_x>=cursor_x)?(pixel_x-cursor_x):(cursor_x-pixel_x);
    wire [9:0] ady = (pixel_y>=cursor_y)?(pixel_y-cursor_y):(cursor_y-pixel_y);
    wire cursor_hit = (adx<=CUR)&&(ady<=CUR);

    wire [7:0] remaining = (seconds>=LIMIT_SEC)?8'd0:(LIMIT_SEC-seconds);
    wire [19:0] rw20 = remaining*BAR_FULL_W/LIMIT_SEC;
    wire [9:0] remaining_w = rw20[9:0];
    wire in_bar_row = (pixel_y>=BAR_TOP)&&(pixel_y<BAR_BOT);
    wire in_bar_fill = in_bar_row&&(pixel_x>=BAR_LEFT)&&(pixel_x<BAR_LEFT+remaining_w);
    wire bar_hit = bar_on && in_bar_fill;
    reg [3:0] bar_r,bar_g,bar_b;
    always @(*) begin
        if (remaining > (LIMIT_SEC*2)/3) begin bar_r=4'h0;bar_g=4'hF;bar_b=4'h0; end
        else if (remaining > LIMIT_SEC/3) begin bar_r=4'hF;bar_g=4'hA;bar_b=4'h0; end
        else begin bar_r=4'hF;bar_g=4'h0;bar_b=4'h0; end
    end

    // ---- MENU text: "START" centered ----
    // 5 chars, SCALE 6 -> 8*6=48 px each, total 240 wide. X0=(640-240)/2=200, Y0=200
    wire [39:0] menu_glyphs = {5'd0,5'd0,5'd0, 5'd11,5'd13,5'd12,5'd11,5'd10}; // S T A R T
    wire menu_text_on;
    text_overlay #(.X0(200),.Y0(200),.SCALE(6),.NCHAR(5)) menu_txt(
        .pixel_x(pixel_x), .pixel_y(pixel_y), .glyphs(menu_glyphs), .text_on(menu_text_on));

    // ---- END text: "SCORE" + the number ----
    // line 1: "SCORE" (5 chars). line 2: 3 score digits.
    wire [39:0] score_word = {5'd0,5'd0,5'd0, 5'd15,5'd13,5'd17,5'd16,5'd10}; // S C O R E
    wire end_word_on;
    text_overlay #(.X0(200),.Y0(150),.SCALE(6),.NCHAR(5)) end_word(
        .pixel_x(pixel_x), .pixel_y(pixel_y), .glyphs(score_word), .text_on(end_word_on));

    wire [4:0] gh = (game_score>=100) ? (game_score/100)     : 5'd18;
    wire [4:0] gt = (game_score>=10)  ? ((game_score/10)%10) : 5'd18;
    wire [4:0] go = game_score%10;
    wire [39:0] num_glyphs = {25'd0, go, gt, gh}; // hundreds,tens,ones left->right
    wire end_num_on;
    text_overlay #(.X0(250),.Y0(260),.SCALE(8),.NCHAR(3)) end_num(
        .pixel_x(pixel_x), .pixel_y(pixel_y), .glyphs(num_glyphs), .text_on(end_num_on));

    wire menu_on = is_menu     && menu_text_on;
    wire end_on  = is_gameover && (end_word_on || end_num_on);

    // ---- pipeline align ----
    reg video_d,target_d,cursor_d,border_d,bar_d,menu_d,end_d;
    reg [3:0] bar_r_d,bar_g_d,bar_b_d;
    always @(posedge clk) begin
        video_d<=video_on; target_d<=target_on; cursor_d<=cursor_hit;
        border_d<=border_hit; bar_d<=bar_hit;
        menu_d<=menu_on; end_d<=end_on;
        bar_r_d<=bar_r; bar_g_d<=bar_g; bar_b_d<=bar_b;
    end

    // ---- colour mux. priority: blank > text(menu/end) > cursor > bar > drawing > target > border > bg
    always @(posedge clk) begin
        if (!video_d) begin vga_r<=4'h0;vga_g<=4'h0;vga_b<=4'h0; end
        else if (menu_d) begin vga_r<=4'hF;vga_g<=4'hF;vga_b<=4'h0; end   // menu text yellow
        else if (end_d)  begin vga_r<=4'hF;vga_g<=4'hF;vga_b<=4'hF; end   // end text white
        else if (cursor_d) begin vga_r<=4'hF;vga_g<=4'h0;vga_b<=4'h0; end
        else if (bar_d) begin vga_r<=bar_r_d;vga_g<=bar_g_d;vga_b<=bar_b_d; end
        else if (pixel_on) begin vga_r<=4'hF;vga_g<=4'hF;vga_b<=4'hF; end
        else if (target_d) begin vga_r<=4'h0;vga_g<=4'hF;vga_b<=4'h0; end
        else if (border_d) begin
            if (!show_score) begin vga_r<=4'h3;vga_g<=4'h3;vga_b<=4'h3; end
            else if (score>=7'd70) begin vga_r<=4'h0;vga_g<=4'hF;vga_b<=4'h0; end
            else if (score>=7'd40) begin vga_r<=4'hF;vga_g<=4'hA;vga_b<=4'h0; end
            else begin vga_r<=4'hF;vga_g<=4'h0;vga_b<=4'h0; end
        end else begin vga_r<=4'h1;vga_g<=4'h1;vga_b<=4'h2; end
    end
endmodule

module text_overlay #(
    parameter integer X0 = 100,
    parameter integer Y0 = 100,
    parameter integer SCALE = 4,      // each font pixel = SCALE x SCALE screen px
    parameter integer NCHAR = 5
)(
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    input  wire [39:0] glyphs,        // glyph[0] in bits [4:0], glyph[1] in [9:5], ...
    output wire text_on
);
    localparam integer CW = 8*SCALE;  // char cell width in px
    localparam integer CH = 8*SCALE;  // char cell height in px
    localparam integer TOTW = CW*NCHAR;

    // are we inside the text band?
    wire in_y = (pixel_y >= Y0) && (pixel_y < Y0 + CH);
    wire in_x = (pixel_x >= X0) && (pixel_x < X0 + TOTW);

    // offset within the text block
    wire [9:0] rel_x = pixel_x - X0;
    wire [9:0] rel_y = pixel_y - Y0;

    // which character, and the pixel within it
    wire [3:0] char_idx = rel_x / CW;          // 0..NCHAR-1
    wire [9:0] cx = rel_x % CW;                 // 0..CW-1
    wire [2:0] font_col = cx / SCALE;           // 0..7
    wire [2:0] font_row = rel_y / SCALE;        // 0..7

    // pick this character's glyph code
    wire [4:0] ch_code = glyphs[char_idx*5 +: 5];

    wire [7:0] row_bits;
    font_rom fr(.ch(ch_code), .row(font_row), .bits(row_bits));

    // bit7 = leftmost column
    wire pix_lit = row_bits[7 - font_col];

    assign text_on = in_x && in_y && pix_lit;
endmodule

module font_rom(
    input  wire [4:0] ch,    // glyph code 0..18
    input  wire [2:0] row,   // 0..7
    output reg  [7:0] bits
);
    always @(*) begin
        case (ch)
        // ---- digits ----
        5'd0: case(row) // 0
            0: bits=8'b00111100; 1: bits=8'b01100110; 2: bits=8'b01101110;
            3: bits=8'b01110110; 4: bits=8'b01100110; 5: bits=8'b01100110;
            6: bits=8'b00111100; default: bits=8'b00000000; endcase
        5'd1: case(row) // 1
            0: bits=8'b00011000; 1: bits=8'b00111000; 2: bits=8'b00011000;
            3: bits=8'b00011000; 4: bits=8'b00011000; 5: bits=8'b00011000;
            6: bits=8'b01111110; default: bits=8'b00000000; endcase
        5'd2: case(row) // 2
            0: bits=8'b00111100; 1: bits=8'b01100110; 2: bits=8'b00000110;
            3: bits=8'b00001100; 4: bits=8'b00110000; 5: bits=8'b01100000;
            6: bits=8'b01111110; default: bits=8'b00000000; endcase
        5'd3: case(row) // 3
            0: bits=8'b00111100; 1: bits=8'b01100110; 2: bits=8'b00000110;
            3: bits=8'b00011100; 4: bits=8'b00000110; 5: bits=8'b01100110;
            6: bits=8'b00111100; default: bits=8'b00000000; endcase
        5'd4: case(row) // 4
            0: bits=8'b00001100; 1: bits=8'b00011100; 2: bits=8'b00111100;
            3: bits=8'b01101100; 4: bits=8'b01111110; 5: bits=8'b00001100;
            6: bits=8'b00001100; default: bits=8'b00000000; endcase
        5'd5: case(row) // 5
            0: bits=8'b01111110; 1: bits=8'b01100000; 2: bits=8'b01111100;
            3: bits=8'b00000110; 4: bits=8'b00000110; 5: bits=8'b01100110;
            6: bits=8'b00111100; default: bits=8'b00000000; endcase
        5'd6: case(row) // 6
            0: bits=8'b00111100; 1: bits=8'b01100000; 2: bits=8'b01111100;
            3: bits=8'b01100110; 4: bits=8'b01100110; 5: bits=8'b01100110;
            6: bits=8'b00111100; default: bits=8'b00000000; endcase
        5'd7: case(row) // 7
            0: bits=8'b01111110; 1: bits=8'b00000110; 2: bits=8'b00001100;
            3: bits=8'b00011000; 4: bits=8'b00110000; 5: bits=8'b00110000;
            6: bits=8'b00110000; default: bits=8'b00000000; endcase
        5'd8: case(row) // 8
            0: bits=8'b00111100; 1: bits=8'b01100110; 2: bits=8'b01100110;
            3: bits=8'b00111100; 4: bits=8'b01100110; 5: bits=8'b01100110;
            6: bits=8'b00111100; default: bits=8'b00000000; endcase
        5'd9: case(row) // 9
            0: bits=8'b00111100; 1: bits=8'b01100110; 2: bits=8'b01100110;
            3: bits=8'b00111110; 4: bits=8'b00000110; 5: bits=8'b00000110;
            6: bits=8'b00111100; default: bits=8'b00000000; endcase
        // ---- letters ----
        5'd10: case(row) // S
            0: bits=8'b00111110; 1: bits=8'b01100000; 2: bits=8'b01100000;
            3: bits=8'b00111100; 4: bits=8'b00000110; 5: bits=8'b00000110;
            6: bits=8'b01111100; default: bits=8'b00000000; endcase
        5'd11: case(row) // T
            0: bits=8'b01111110; 1: bits=8'b00011000; 2: bits=8'b00011000;
            3: bits=8'b00011000; 4: bits=8'b00011000; 5: bits=8'b00011000;
            6: bits=8'b00011000; default: bits=8'b00000000; endcase
        5'd12: case(row) // A
            0: bits=8'b00111100; 1: bits=8'b01100110; 2: bits=8'b01100110;
            3: bits=8'b01111110; 4: bits=8'b01100110; 5: bits=8'b01100110;
            6: bits=8'b01100110; default: bits=8'b00000000; endcase
        5'd13: case(row) // R
            0: bits=8'b01111100; 1: bits=8'b01100110; 2: bits=8'b01100110;
            3: bits=8'b01111100; 4: bits=8'b01101100; 5: bits=8'b01100110;
            6: bits=8'b01100110; default: bits=8'b00000000; endcase
        5'd14: case(row) // P
            0: bits=8'b01111100; 1: bits=8'b01100110; 2: bits=8'b01100110;
            3: bits=8'b01111100; 4: bits=8'b01100000; 5: bits=8'b01100000;
            6: bits=8'b01100000; default: bits=8'b00000000; endcase
        5'd15: case(row) // E
            0: bits=8'b01111110; 1: bits=8'b01100000; 2: bits=8'b01100000;
            3: bits=8'b01111100; 4: bits=8'b01100000; 5: bits=8'b01100000;
            6: bits=8'b01111110; default: bits=8'b00000000; endcase
        5'd16: case(row) // C
            0: bits=8'b00111100; 1: bits=8'b01100110; 2: bits=8'b01100000;
            3: bits=8'b01100000; 4: bits=8'b01100000; 5: bits=8'b01100110;
            6: bits=8'b00111100; default: bits=8'b00000000; endcase
        5'd17: case(row) // O
            0: bits=8'b00111100; 1: bits=8'b01100110; 2: bits=8'b01100110;
            3: bits=8'b01100110; 4: bits=8'b01100110; 5: bits=8'b01100110;
            6: bits=8'b00111100; default: bits=8'b00000000; endcase
        default: bits=8'b00000000; // blank
        endcase
    end
endmodule

module vga_controller(
input wire clk,        // 100 MHz system clock
input wire rst,        // reset
output wire hsync,      // horizontal sync (active low)
output wire vsync,      // vertical sync   (active low)
output wire [9:0] pixel_x,    // current column (0..639 when visible)
output wire [9:0] pixel_y,    // current row    (0..479 when visible)
output wire video_on,   // 1 inside the visible area
output wire p_tick      // 25 MHz pixel-clock enable
);

// ---- timing constants ----
localparam H_VISIBLE = 640, H_FRONT = 16, H_SYNC = 96, H_TOTAL = 800;
localparam V_VISIBLE = 480, V_FRONT = 10, V_SYNC = 2,  V_TOTAL = 525;

// ---- pixel-clock enable: 100 MHz / 4 = 25 MHz ----
reg [1:0] pix_div = 2'b0;
always @(posedge clk) 
pix_div <= pix_div + 1'b1;
wire pix_en = (pix_div == 2'b11);
assign 
p_tick = pix_en;

// ---- horizontal & vertical position counters ----
reg [9:0] h_count = 10'd0;
reg [9:0] v_count = 10'd0;
always @(posedge clk) begin
if (rst) begin
    h_count <= 10'd0;
    v_count <= 10'd0;
end 
else if (pix_en) 
begin
if (h_count == H_TOTAL-1) 
begin       // end of a line
h_count <= 10'd0;
if (v_count == V_TOTAL-1)         // end of a frame
    v_count <= 10'd0;
else
    v_count <= v_count + 1'b1;
end 
else 
begin
    h_count <= h_count + 1'b1;
end
end
end

// ---- active-low sync pulses ----
assign 
hsync = ~((h_count >= H_VISIBLE + H_FRONT) && (h_count <  H_VISIBLE + H_FRONT + H_SYNC));
assign 
vsync = ~((v_count >= V_VISIBLE + V_FRONT) && (v_count <  V_VISIBLE + V_FRONT + V_SYNC));

// ---- visible region and pixel coordinates ----
assign 
video_on = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
assign 
pixel_x  = h_count;
assign 
pixel_y  = v_count;

endmodule

module score_display #(
parameter integer REFRESH_BITS = 18   // ~381 Hz/digit at 100 MHz (lower in sim)
)
(
input wire clk,
input wire show_score,   // 1 = display the score, 0 = blank
input wire [6:0] score,        // 0..100
output reg [6:0] seg,          // seg[0]=CA ... seg[6]=CG (active low: 0=on)
output reg dp,           // decimal point (active low: 1=off)
output reg [7:0] an            // digit anodes (active low: 0=on)
);
// split the score into decimal digits
wire [3:0] ones = score % 10;
wire [3:0] tens = (score / 10) % 10;
wire [3:0] hundreds = score / 100;          // 0 or 1

// free-running counter -> selects which digit is lit right now
reg [REFRESH_BITS+1:0] refresh = 0;
always @(posedge clk) refresh <= refresh + 1'b1;
wire [1:0] digit_sel = refresh[REFRESH_BITS+1:REFRESH_BITS];

// 7-seg decoder, active low. index 0=a,1=b,2=c,3=d,4=e,5=f,6=g
function [6:0] seg7;
input [3:0] d;
begin
case (d)
    4'd0: seg7 = 7'b1000000;
    4'd1: seg7 = 7'b1111001;
    4'd2: seg7 = 7'b0100100;
    4'd3: seg7 = 7'b0110000;
    4'd4: seg7 = 7'b0011001;
    4'd5: seg7 = 7'b0010010;
    4'd6: seg7 = 7'b0000010;
    4'd7: seg7 = 7'b1111000;
    4'd8: seg7 = 7'b0000000;
    4'd9: seg7 = 7'b0010000;
default: 
    seg7 = 7'b1111111;   // blank
endcase
end
endfunction

always @(*) begin
dp = 1'b1;                        // decimal point always off
if (!show_score) begin
    an  = 8'b1111_1111;           // all digits off
    seg = 7'b1111111;             // blank
end 

else 
begin
case (digit_sel)
2'd0: 
begin               // ones digit on AN0
    an  = 8'b1111_1110;
    seg = seg7(ones);
end
2'd1:
begin               // tens digit on AN1 (blank if score<10)
    an  = 8'b1111_1101;
    seg = (score < 7'd10) ? 7'b1111111 : seg7(tens);
end
2'd2: 
begin               // hundreds digit on AN2 (blank if score<100)
    an  = 8'b1111_1011;
    seg = (score < 7'd100) ? 7'b1111111 : seg7(hundreds);
end
default: 
begin            // 4th slot unused
    an  = 8'b1111_1111;
    seg = 7'b1111111;
end
endcase
end
end
endmodule

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

module top_module(

input wire iclk,
input wire miso,
input wire rst,
input wire pen_btn,
input wire start_btn,
input wire submit_btn,
input wire next_btn,
output wire sclk,
output wire mosi,
output wire cs,           
output wire [3:0] vga_r,   
output wire [3:0] vga_g,   
output wire [3:0] vga_b,
output wire hsync,      
output wire vsync,
output wire [6:0] seg,
output wire dp,
output wire [7:0] an      
      
);
wire [14:0] acl_data;
wire signed [5:0] tilt_x;     
wire signed [5:0] tilt_y;
wire [9:0] cursor_x;
wire [9:0] cursor_y;
wire [10:0] pixel_x;
wire [9:0] pixel_y;
wire video_on;
wire pixel_on;
wire target_on;
wire [1:0] target_sel;
wire [10:0] cell_x;
wire [9:0] cell_y;
wire [6:0] score;
wire [7:0] game_score;
wire score_ready;
wire pen_down; 
wire draw_enable;
wire clear_canvas;
wire start_calc;
wire show_score;
wire [2:0] state; 
wire p_tick;  
wire target_bit; 
wire game_over = (state == 3'd4);
wire [6:0] disp_score = game_over ? game_score [6:0] : score;
wire start_db;
wire submit_db;
wire next_db;
wire pen_db;
wire timer_done; 
wire start_timer; 
wire stop_timer; 
wire reset_timer;
wire [7:0] seconds;
wire drawing = (state == 3'd1); 

accelerometer_spi_master spi_inst(
.iclk(iclk),
.miso(miso),
.sclk(sclk),
.mosi(mosi),
.cs(cs),
.acl_data(acl_data)
);

tilt_decoder #(
.DEADZONE(1)
)
tilt_inst(
.clk(iclk),
.acl_data(acl_data),
.tilt_x(tilt_x),
.tilt_y(tilt_y)
);

cursor_controller #(
.SCREEN_W (640), 
.SCREEN_H (480), 
.MOVE_DIV (1000000) 
)
cursor_inst(
.clk(iclk), // system clock
.rst(rst), // reset centre the 
.tilt_x(tilt_x),        
.tilt_y(tilt_y),         
.pen_btn(pen_db),        
.cursor_x(cursor_x),       
.cursor_y(cursor_y),        
.pen_down(pen_down) 
);

wire scoring = (state == 3'd2); 
wire [10:0] mem_x = scoring ? (cell_x << 2) : pixel_x;
wire [9:0]  mem_y = scoring ? (cell_y << 2) : pixel_y;
canvas_memory #(
.GRID_W(160),
.GRID_H(120),
.CELL_SHIFT(2)   
)
memory_inst(
.clk(iclk),
.draw_enable(draw_enable),
.cursor_x(cursor_x),       
.cursor_y(cursor_y),
.clear_canvas(clear_canvas),
.pen_down(pen_down),
.pixel_x(mem_x),
.pixel_y(mem_y),
.pixel_on(pixel_on)
); 

game_fsm game_inst(
.clk(iclk),
.rst(rst),
.start_btn(start_db),
.submit_btn(submit_db),
.next_btn(next_db),
.score_ready(score_ready),
.similarity_score(score),
.draw_enable(draw_enable),
.clear_canvas(clear_canvas),
.start_calc(start_calc),
.show_score(show_score),
.target_sel(target_sel),
.state(state),
.game_score(game_score),
.timer_done(timer_done),
.start_timer(start_timer),
.stop_timer(stop_timer),
.reset_timer(reset_timer) 
);

target_generator #(
.GRID_W(160), 
.GRID_H(120), 
.HALF(40), 
.THICK(2)
)
target_disp(
.target_sel(target_sel),
.cell_x(pixel_x>>2),
.cell_y(pixel_y>>2),
.target_on(target_on)
);

target_generator #(
.GRID_W(160), 
.GRID_H(120), 
.HALF(40), 
.THICK(2)
)
target_score(
.target_sel(target_sel),
.cell_x(cell_x),
.cell_y(cell_y),
.target_on(target_bit)
);

///*reg target_bit_delayed;

//always @(posedge iclk) begin
//target_bit_delayed <= target_bit;
//end*/

similarity_calc #(
.GRID_W(160),
.GRID_H(120)
)
similarity_inst(
.clk(iclk),
.rst(rst),
.start(start_calc),
.cell_x(cell_x),
.cell_y(cell_y),
.canvas_bit(pixel_on),
.target_bit(target_bit),
.score(score),
.score_ready(score_ready)
);

score_display score_inst(
.clk(iclk),
.show_score(show_score),   
.score(disp_score),             
.seg(seg),
.dp(dp),
.an(an)
);

canvas_renderer #(
.LIMIT_SEC(60)
)
canvas_inst(
.clk(iclk),           
.video_on(video_on),    
.pixel_x(pixel_x),     
.pixel_y(pixel_y), 
.pixel_on(pixel_on),    
.target_on(target_on),   
.cursor_x(cursor_x),
.cursor_y(cursor_y),
.score(score),
.show_score(show_score),
.seconds(seconds),       
.bar_on(drawing),
.state(state),              
.game_score(game_score),    
.vga_r(vga_r),   
.vga_g(vga_g),   
.vga_b(vga_b)
);

debounce db_start(
.clk(iclk),
.btn_in(start_btn),  
.btn_clean(),       
.btn_pulse(start_db)
);

debounce db_submit(
.clk(iclk), 
.btn_in(submit_btn), 
.btn_clean(),       
.btn_pulse(submit_db)
);


debounce db_next(
.clk(iclk), 
.btn_in(next_btn),   
.btn_clean(),       
.btn_pulse(next_db)
);

debounce db_pen(
.clk(iclk), 
.btn_in(pen_btn),    
.btn_clean(pen_db), 
.btn_pulse()
);

game_timer #(
.CLK_HZ(100000000), 
.LIMIT_SEC(60)) 
timer_inst(
.clk(iclk), .rst(rst),
.start_timer(start_timer),
.stop_timer(stop_timer),
.reset_timer(reset_timer),
.seconds(seconds),
.timer_done(timer_done)
);

vga_controller vga_inst(
.clk(iclk),        
.rst(rst),        
.hsync(hsync),     
.vsync(vsync),     
.pixel_x(pixel_x), 
.pixel_y(pixel_y), 
.video_on(video_on),
.p_tick(p_tick)
);  
 
endmodule
