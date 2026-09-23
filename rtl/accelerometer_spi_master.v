module accelerometer_spi_master(
    input iclk,
    input miso,
    output sclk,
    output reg mosi = 1'b0,
    output reg cs = 1'b1,
    output [140] acl_data
    );
    cntrl sclk output for spi mode 
    reg sclk_control = 1'b0;
    
    reg clk_counter = 1'b0;
    reg clk_reg = 1'b1;
    
    always@(posedge iclk) 
    begin
        clk_counter = clk_counter + 1;
        if(clk_counter == 1'b1)
            clk_reg = ~clk_reg;
    end
    
    reg [70] write_instr   = 8'h0A;
    reg [70] mode_reg_addr = 8'h2D;
    reg [70] mode_wr_data  = 8'h02;
    reg [70] read_instr    = 8'h0B;
    reg [70] x_LSB_addr    = 8'h0E;
    reg [140] temp_DATA    = 15'b0;
    reg [150] X;
    reg [150] Y;
    reg [150] Z;
    reg [310] counter = 32'b0;
    wire latch_data;
    
    93 states for state machine
    localparam [60] POWER_UP    = 7'h00,
                    SPI WRITE
                    BEGIN_SPIW = 7'h01,
                    send write instruction 0x0A
                    SEND_WCMD7  = 7'h02,
                    SEND_WCMD6  = 7'h03,
                    SEND_WCMD5  = 7'h04,
                    SEND_WCMD4  = 7'h05,
                    SEND_WCMD3  = 7'h06,
                    SEND_WCMD2  = 7'h07,
                    SEND_WCMD1  = 7'h08,
                    SEND_WCMD0  = 7'h09,
                     send register addess to write to 0x2D
                    SEND_WADDR7 = 7'h0A,
                    SEND_WADDR6 = 7'h0B,
                    SEND_WADDR5 = 7'h0C,
                    SEND_WADDR4 = 7'h0D,
                    SEND_WADDR3 = 7'h0E,
                    SEND_WADDR2 = 7'h0F,
                    SEND_WADDR1 = 7'h10,
                    SEND_WADDR0 = 7'h11,
                    send byte to put into measurement mode 0x02
                    SEND_BYTE7  = 7'h12,
                    SEND_BYTE6  = 7'h13,
                    SEND_BYTE5  = 7'h14,
                    SEND_BYTE4  = 7'h15,
                    SEND_BYTE3  = 7'h16,
                    SEND_BYTE2  = 7'h17,
                    SEND_BYTE1  = 7'h18,
                    SEND_BYTE0  = 7'h19,
                    wait for first valid date after init measurement mode = 40ms
                    WAIT = 7'h1A,
                    spi read
                    BEGIN_SPIR  = 7'h1B,
                    send read instructio 0x0B
                    SEND_RCMD7  = 7'h1C,
                    SEND_RCMD6  = 7'h1D,
                    SEND_RCMD5  = 7'h1E,
                    SEND_RCMD4  = 7'h1F,
                    SEND_RCMD3  = 7'h20,
                    SEND_RCMD2  = 7'h21,  
                    SEND_RCMD1  = 7'h22,
                    SEND_RCMD0  = 7'h23,
                    send X data LSB register address 0x0E
                    SEND_RADDR7 = 7'h24,
                    SEND_RADDR6 = 7'h25,
                    SEND_RADDR5 = 7'h26,
                    SEND_RADDR4 = 7'h27,
                    SEND_RADDR3 = 7'h28,
                    SEND_RADDR2 = 7'h29,
                    SEND_RADDR1 = 7'h2A,
                    SEND_RADDR0 = 7'h2B,
                    receive X data LSB fron 0x0E
                    REC_XLSB7   = 7'h2C,
                    REC_XLSB6   = 7'h2D,
                    REC_XLSB5   = 7'h2E,
                    REC_XLSB4   = 7'h2F,
                    REC_XLSB3   = 7'h30,
                    REC_XLSB2   = 7'h31,
                    REC_XLSB1   = 7'h32,
                    REC_XLSB0   = 7'h33,  
                    receive X data MSB from 0x0F
                    REC_XMSB7   = 7'h34,
                    REC_XMSB6   = 7'h35,  
                    REC_XMSB5   = 7'h36,   
                    REC_XMSB4   = 7'h37,   
                    REC_XMSB3   = 7'h38,   
                    REC_XMSB2   = 7'h39,   
                    REC_XMSB1   = 7'h3A,   
                    REC_XMSB0   = 7'h3B,  
                    receive Y data LSB fron 0x0E 
                    REC_YLSB7   = 7'h3C,
                    REC_YLSB6   = 7'h3D,
                    REC_YLSB5   = 7'h3E,
                    REC_YLSB4   = 7'h3F,
                    REC_YLSB3   = 7'h40,
                    REC_YLSB2   = 7'h41,
                    REC_YLSB1   = 7'h42,
                    REC_YLSB0   = 7'h43,
                    receive Y data MSB from 0x0F
                    REC_YMSB7   = 7'h44,
                    REC_YMSB6   = 7'h45,  
                    REC_YMSB5   = 7'h46,   
                    REC_YMSB4   = 7'h47,   
                    REC_YMSB3   = 7'h48,   
                    REC_YMSB2   = 7'h49,   
                    REC_YMSB1   = 7'h4A,   
                    REC_YMSB0   = 7'h4B, 
                    receive Z data LSB fron 0x0E 
                    REC_ZLSB7   = 7'h4C,
                    REC_ZLSB6   = 7'h4D,
                    REC_ZLSB5   = 7'h4E,
                    REC_ZLSB4   = 7'h4F,
                    REC_ZLSB3   = 7'h50,
                    REC_ZLSB2   = 7'h51,
                    REC_ZLSB1   = 7'h52,
                    REC_ZLSB0   = 7'h53,
                    receive Z data MSB from 0x0F
                    REC_ZMSB7   = 7'h54,
                    REC_ZMSB6   = 7'h55,  
                    REC_ZMSB5   = 7'h56,   
                    REC_ZMSB4   = 7'h57,   
                    REC_ZMSB3   = 7'h58,   
                    REC_ZMSB2   = 7'h59,   
                    REC_ZMSB1   = 7'h5A,   
                    REC_ZMSB0   = 7'h5B, 
                    end SPI commmunications 
                    END_SPI     = 7'h5C;    wait 10ms, CS = 0, SCLK = idle = 0, loop back to BEGIN_SPIW
    state register 
    reg [60] state_reg = POWER_UP;
    
    always @(posedge iclk) 
    begin   
        counter = counter +  1;    increment statemachine sync counter
        case(state_reg)
            POWER_UP    
            begin
                if(counter == 32'd23999)    wait for 6ms, for sensor to reach standby mode
                    state_reg = BEGIN_SPIW;
            end
    begin SPI write command to initiate a write sequence
            BEGIN_SPIW   
            begin
                if(counter == 32'd24001)
                    begin 
                    state_reg = SEND_WCMD7;
                    cs = 1'b0;
                    end
            end
    send the write command to initiate a write sequence
    SEND_WCMD7  
    begin
        sclk_control = 1'b1;
        mosi = write_instr[7];
        if(counter == 32'd24005)
            state_reg = SEND_WCMD6;
    end 
    SEND_WCMD6  
    begin
        mosi = write_instr[6];
        if(counter == 32'd24009)
            state_reg = SEND_WCMD5;
        end
    SEND_WCMD5  
    begin
        mosi = write_instr[5];
        if(counter == 32'd24013)
            state_reg = SEND_WCMD4;
        end
    SEND_WCMD4  
    begin
        mosi = write_instr[4];
        if(counter == 32'd24017)
            state_reg = SEND_WCMD3;
        end
    SEND_WCMD3  
    begin
        mosi = write_instr[3];
        if(counter == 32'd24021)
            state_reg = SEND_WCMD2;
        end
    SEND_WCMD2  
    begin
        mosi = write_instr[2];
        if(counter == 32'd24025)
            state_reg = SEND_WCMD1;
    end
    SEND_WCMD1  
    begin
        mosi = write_instr[1];
        if(counter == 32'd24029)
            state_reg = SEND_WCMD0;
    end
    SEND_WCMD0  
    begin
        mosi = write_instr[0];
        if(counter == 32'd24033)
            state_reg = SEND_WADDR7;
    end
    send address to write to, in this case the 0x2D register, to configure sensor to measurement mode
    SEND_WADDR7  
    begin
        mosi = mode_reg_addr[7];
        if(counter == 32'd24037)
            state_reg = SEND_WADDR6;
    end
    SEND_WADDR6  
    begin
        mosi = mode_reg_addr[6];
        if(counter == 32'd24041)
            state_reg = SEND_WADDR5;
    end
    SEND_WADDR5  
    begin
        mosi = mode_reg_addr[5];
        if(counter == 32'd24045)
            state_reg = SEND_WADDR4;
    end
    SEND_WADDR4  
    begin
        mosi = mode_reg_addr[4];
        if(counter == 32'd24049)
            state_reg = SEND_WADDR3;
    end
    SEND_WADDR3  
    begin
        mosi = mode_reg_addr[3];
        if(counter == 32'd24053)
            state_reg = SEND_WADDR2;
    end
    SEND_WADDR2  
    begin
        mosi = mode_reg_addr[2];
        if(counter == 32'd24057)
            state_reg = SEND_WADDR1;
    end
    SEND_WADDR1  
    begin
        mosi = mode_reg_addr[1];
        if(counter == 32'd24061)
            state_reg = SEND_WADDR0;
    end
    SEND_WADDR0  
    begin
        mosi = mode_reg_addr[0];
        if(counter == 32'd24065)
            state_reg = SEND_BYTE7;
    end
    send value to write to the 0x2D register, ijn this case 0x02, for measurement mode 
    SEND_BYTE7  
    begin
        mosi = mode_wr_data[7];
        if(counter == 32'd24069)
            state_reg = SEND_BYTE6;
    end
    SEND_BYTE6  
    begin
        mosi = mode_wr_data[6];
        if(counter == 32'd24073)
            state_reg = SEND_BYTE5;
    end
    SEND_BYTE5  
    begin
        mosi = mode_wr_data[5];
        if(counter == 32'd24077)
            state_reg = SEND_BYTE4;
    end
    SEND_BYTE4  
    begin
        mosi = mode_wr_data[4];
        if(counter == 32'd24081)
            state_reg = SEND_BYTE3;
    end
    SEND_BYTE3  
    begin
        mosi = mode_wr_data[3];
        if(counter == 32'd24085)
            state_reg = SEND_BYTE2;
    end
    SEND_BYTE2  
    begin
        mosi = mode_wr_data[2];
        if(counter == 32'd24089)
            state_reg = SEND_BYTE1;
    end
    SEND_BYTE1  
    begin
        mosi = mode_wr_data[1];
        if(counter == 32'd24093)
            state_reg = SEND_BYTE0;
    end
    SEND_BYTE0  
    begin
        mosi = mode_wr_data[0];
        if(counter == 32'd24097) 
        begin
            state_reg = WAIT;
            counter = 32'd0;
            cs = 1'b1;
            sclk_control = 1'b0;
        end
    end
    eait for 40ms after setting measurement mode to allow the first valis=d data, 160000 ticks+ 3 to line up SCLK
    WAIT    
    begin
        if(counter == 32'd160002)
        begin
            counter = 32'd0;
            state_reg = BEGIN_SPIR;
        end
    end
    begin SPI read communication with sensor by sending CS low 
    BEGIN_SPIR  
    begin
        if(counter == 32'd1)
        begin 
            state_reg = SEND_RCMD7;
            cs = 1'b0;
            sclk_control = 1'b1;
        end 
    end
    send the read command to initiate a read sequence 
    SEND_RCMD7  
    begin
        mosi = read_instr[7];
        if(counter == 32'd4)
            state_reg = SEND_RCMD6;
        end
        SEND_RCMD6  
    begin
        mosi = read_instr[6];
        if(counter == 32'd8)
            state_reg = SEND_RCMD5;
        end
        SEND_RCMD5  
    begin
        mosi = read_instr[5];
        if(counter == 32'd12)
            state_reg = SEND_RCMD4;
        end
        SEND_RCMD4  
    begin
        mosi = read_instr[4];
        if(counter == 32'd16)
            state_reg = SEND_RCMD3;
        end
        SEND_RCMD3  
    begin
        mosi = read_instr[3];
        if(counter == 32'd20)
            state_reg = SEND_RCMD2;
        end
        SEND_RCMD2  
    begin
        mosi = read_instr[2];
        if(counter == 32'd24)
            state_reg = SEND_RCMD1;
        end
        SEND_RCMD1  
    begin
        mosi = read_instr[1];
        if(counter == 32'd28)
            state_reg = SEND_RCMD0;
        end
        SEND_RCMD0  
    begin
        mosi = read_instr[0];
        if(counter == 32'd32)
            state_reg = SEND_RADDR7;
        end
send register address to read from, in this case 0x0E, the x data LSB
    SEND_RADDR7 
        begin 
            mosi = x_LSB_addr[7];
            if(counter == 32'd36)
                state_reg = SEND_RADDR6;
        end
     SEND_RADDR6 
        begin 
            mosi = x_LSB_addr[6];
            if(counter == 32'd40)
                state_reg = SEND_RADDR5;
        end
     SEND_RADDR5 
        begin 
            mosi = x_LSB_addr[5];
            if(counter == 32'd44)
                state_reg = SEND_RADDR4;
        end
    SEND_RADDR4 
        begin 
            mosi = x_LSB_addr[4];
            if(counter == 32'd48)
                state_reg = SEND_RADDR3;
        end
    SEND_RADDR3 
        begin 
            mosi = x_LSB_addr[3];
            if(counter == 32'd52)
                state_reg = SEND_RADDR2;
        end
    SEND_RADDR2 
        begin 
            mosi = x_LSB_addr[2];
            if(counter == 32'd56)
                state_reg = SEND_RADDR1;
        end
    SEND_RADDR1 
        begin 
            mosi = x_LSB_addr[1];
            if(counter == 32'd60)
                state_reg = SEND_RADDR0;
        end
    SEND_RADDR0 
        begin 
            mosi = x_LSB_addr[0];
            if(counter == 32'd64)
                state_reg = REC_XLSB7;
        end
receive x data LSB[70], store in LSB of X data reg
    REC_XLSB7    
        begin
            X[7] = miso;
            if(counter == 32'd68)
                state_reg = REC_XLSB6;
        end
    REC_XLSB6    
        begin
            X[6] = miso;
            if(counter == 32'd72)
                state_reg = REC_XLSB5;
        end 
    REC_XLSB5    
        begin
            X[5] = miso;
            if(counter == 32'd76)
                state_reg = REC_XLSB4;
        end
    REC_XLSB4    
        begin
            X[4] = miso;
            if(counter == 32'd80)
                state_reg = REC_XLSB3;
        end
    REC_XLSB3    
        begin
            X[3] = miso;
            if(counter == 32'd84)
                state_reg = REC_XLSB2;
        end
    REC_XLSB2    
        begin
            X[2] = miso;
            if(counter == 32'd88)
                state_reg = REC_XLSB1;
        end
    REC_XLSB1    
        begin
            X[1] = miso;
            if(counter == 32'd92)
                state_reg = REC_XLSB0;
        end
   REC_XLSB0    
        begin
            X[0] = miso;
            if(counter == 32'd96)
                state_reg = REC_XMSB7;
        end
receive x data MSB[70], store in MSB of X data reg
    REC_XMSB7   
        begin
            X[15] = miso;
            if(counter == 32'd100)
                state_reg= REC_XMSB6;
        end
    REC_XMSB6   
        begin
            X[14] = miso;
            if(counter == 32'd104)
                state_reg= REC_XMSB5;
        end
    REC_XMSB5   
        begin
            X[13] = miso;
            if(counter == 32'd108)
                state_reg = REC_XMSB4;
        end
   REC_XMSB4   
        begin
            X[12] = miso;
            if(counter == 32'd112)
                state_reg = REC_XMSB3;
        end
   REC_XMSB3   
        begin
            X[11] = miso;
            if(counter == 32'd116)
                state_reg = REC_XMSB2;
        end
   REC_XMSB2   
        begin
            X[10] = miso;
            if(counter == 32'd120)
                state_reg = REC_XMSB1;
        end
   REC_XMSB1   
        begin
            X[9] = miso;
            if(counter == 32'd124)
                state_reg = REC_XMSB0;
        end
   REC_XMSB0    
        begin 
            X[8] = miso;
            if(counter == 32'd128)
                state_reg = REC_YLSB7;
        end
receive y data LSB[70], store in LSB of Y data reg        
    REC_YLSB7   
        begin
            Y[7] = miso;
            if(counter == 32'd132)
                state_reg = REC_YLSB6;
        end
   REC_YLSB6   
        begin
            Y[6] = miso;
            if(counter == 32'd136)
                state_reg = REC_YLSB5;
        end
   REC_YLSB5   
        begin
            Y[5] = miso;
            if(counter == 32'd140)
                state_reg = REC_YLSB4;
        end
   REC_YLSB4   
        begin
            Y[4] = miso;
            if(counter == 32'd144)
                state_reg = REC_YLSB3;
        end
    REC_YLSB3   
        begin
            Y[3] = miso;
            if(counter == 32'd148)
                state_reg = REC_YLSB2;
        end
    REC_YLSB2   
        begin
            Y[2] = miso;
            if(counter == 32'd152)
                state_reg = REC_YLSB1;
        end
    REC_YLSB1   
        begin
            Y[1] = miso;
            if(counter == 32'd156)
                state_reg = REC_YLSB0;
        end
    REC_YLSB0   
        begin
            Y[0] = miso;
            if(counter == 32'd160)
                state_reg = REC_YMSB7;
        end
receive Y data MSB[70], store in MSB of Y data reg
    REC_YMSB7   
        begin
            Y[15] = miso;
            if(counter == 32'd164)
                state_reg = REC_YMSB6;
        end
    REC_YMSB6   
        begin
            Y[14] = miso;
            if(counter == 32'd168)
                state_reg = REC_YMSB5;
        end
    REC_YMSB5   
        begin
            Y[13] = miso;
            if(counter == 32'd172)
                state_reg = REC_YMSB4;
        end
    REC_YMSB4   
        begin
            Y[12] = miso;
            if(counter == 32'd176)
                state_reg = REC_YMSB3;
        end
    REC_YMSB3   
        begin
            Y[11] = miso;
            if(counter == 32'd180)
                state_reg = REC_YMSB2;
        end
    REC_YMSB2   
        begin
            Y[10] = miso;
            if(counter == 32'd184)
                state_reg = REC_YMSB1;
        end
    REC_YMSB1   
        begin
            Y[9] = miso;
            if(counter == 32'd188)
                state_reg = REC_YMSB0;
        end
    REC_YMSB0   
        begin
            Y[8] = miso;
            if(counter == 32'd192)
                state_reg = REC_ZLSB7;
        end
receive Z data LSB[70], store in LSB of Z data reg
    REC_ZLSB7   
        begin
            Z[7] = miso;
            if(counter == 32'd196)
                state_reg = REC_ZLSB6;
        end
    REC_ZLSB6   
        begin
            Z[6] = miso;
            if(counter == 32'd200)
                state_reg = REC_ZLSB5;
        end
    REC_ZLSB5   
        begin
            Z[5] = miso;
            if(counter == 32'd204)
                state_reg = REC_ZLSB4;
        end
    REC_ZLSB4   
        begin
            Z[4] = miso;
            if(counter == 32'd208)
                state_reg = REC_ZLSB3;
        end
    REC_ZLSB3   
        begin
            Z[3] = miso;
            if(counter == 32'd212)
                state_reg = REC_ZLSB2;
        end
    REC_ZLSB2   
        begin
            Z[2] = miso;
            if(counter == 32'd216)
                state_reg = REC_ZLSB1;
        end
    REC_ZLSB1   
        begin
            Z[1] = miso;
            if(counter == 32'd220)
                state_reg = REC_ZLSB0;
        end
    REC_ZLSB0   
        begin
            Z[0] = miso;
            if(counter == 32'd224)
                state_reg = REC_ZMSB7;
        end
receive Y data MSB[70], store in MSB of Y data reg
    REC_ZMSB7   
        begin
            Z[15] = miso;
            if(counter == 32'd228)
                state_reg = REC_ZMSB6;
        end
    REC_ZMSB6   
        begin
            Z[14] = miso;
            if(counter == 32'd232)
                state_reg = REC_ZMSB5;
        end
    REC_ZMSB5   
        begin
            Z[13] = miso;
            if(counter == 32'd236)
                state_reg = REC_ZMSB4;
        end
    REC_ZMSB4   
        begin
            Z[12] = miso;
            if(counter == 32'd240)
                state_reg = REC_ZMSB3;
        end
    REC_ZMSB3   
        begin
            Z[11] = miso;
            if(counter == 32'd244)
                state_reg = REC_ZMSB2;
        end
    REC_ZMSB2   
        begin
            Z[10] = miso;
            if(counter == 32'd248)
                state_reg = REC_ZMSB1;
        end
    REC_ZMSB1   
        begin
            Z[9] = miso;
            if(counter == 32'd252)
                state_reg = REC_ZMSB0;
        end
    REC_ZMSB0   
        begin
            Z[8] = miso;
            if(counter == 32'd256)
            begin
                cs = 1'b1;
                sclk_control = 1'b0; 
                state_reg = END_SPI;
            end
        end
end read communications, wait 10 =ms for 100Hz data rate = 40000 ticks
    END_SPI 
        begin 
            if(counter == 32'd40259)
            begin
                counter = 32'd0;
                state_reg = BEGIN_SPIR;
            end
        end 
    endcase
end
data buffer 
always @(negedge iclk)
    if(latch_data)
    begin   
        temp_DATA = { X[117], Y[117], Z[117] };
    end
output acclerometer data 
assign acl_data = temp_DATA;

assign latch_data = ((state_reg == END_SPI) && (counter == 32'd258))  10;
assign sclk = (sclk_control)  clk_reg  0;

endmodule