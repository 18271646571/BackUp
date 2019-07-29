//----------------------
//This module is for SCCB control, FPGA is master and camera is slave
//Two wire SCCB, only support single read and single write
//Created by dong on 2019.4.28 
//----------------------


module sccb_control
(
	input wire clk,               // 25Mhz
	input wire reset,             // Reset signal (active-low)
	input wire [11:0] clk_div,    // Clock divider value to configure SDIO_C from system clock
	inout wire sio_d,            // SCCB data (tri-state)
	output wire sio_c,            // SCCB clock
	input wire [6:0] addr,        // Address of device
	input wire [15:0] subaddr,     // Sub-Address (Register) to write to
	input wire [7:0] w_data,      // Data to write to device
	output reg [7:0] r_data, // Data read from device
	input wire wr,           // 1: write ,0 read
	input wire start,
	output reg done
);

reg [11:0] con_div;
reg [7:0] con_w,con_r;
reg [39:0] shiftw;
reg [50:0] shiftr;
reg sio_c_w,sio_c_r;
reg sio_e;
reg [5:0] oew_con,oer_con;
wire sio_d_temp;

always @ (posedge clk or posedge reset) if(reset) con_div <= 12'h0; else if(con_div == clk_div) con_div <= 12'h0; else con_div <= con_div + 1'b1;

always @ (posedge clk or posedge reset) 
begin
	if(reset) con_w <= 8'd0;  
	else if(start&wr) con_w <= 8'd1;
	else if(con_w == 8'd0) con_w <= 8'd0;
	else if(con_w == 8'd158) con_w <= 8'd0;
	else if(con_div == 12'h0) con_w <= con_w+1'b1;
	else con_w <= con_w;
end


always @ (posedge clk or posedge reset) 
begin
	if(reset) con_r <= 8'd0;  
	else if(start&(~wr)) con_r <= 8'd1;
	else if(con_r == 8'd0) con_r <= 8'd0;
	else if(con_r == 8'd202) con_r <= 8'd0;
	else if(con_div == 12'h0) con_r <= con_r+1'b1;
	else con_r <= con_r;
end

always @ (posedge clk or posedge reset) 
begin
	if(reset)
		shiftw <= 40'hffffffffff;
	else if(start&wr)
		shiftw <= {1'b1,1'b0,addr,1'b0,1'b1,subaddr[15:8],1'b1,subaddr[7:0],1'b1,w_data[7:0],1'b1,1'b0,1'b1};
	else if((con_w[1:0]==2'b11)&(con_div == 12'h1))
		shiftw <= {shiftw[38:0],1'b1};
	else 
		shiftw <= shiftw;
end

always @ (posedge clk or posedge reset) 
begin
	if(reset)
		shiftr <= 51'h7ffffffffffff;
	else if(start&(~wr))
		shiftr <= {1'b1,1'b0,addr,1'b0,1'b1,subaddr[15:8],1'b1,subaddr[7:0],1'b1,1'b1,1'b0,addr,1'b1,1'b1,8'hff,1'b0,1'b0,1'b1};
	else if((con_r[1:0]==2'b11)&(con_div == 12'h1))
		shiftr <= {shiftr[49:0],1'b1};
	else
		shiftr <= shiftr;
end

always @ (posedge clk or posedge reset) 
begin
	if(reset)
		oew_con <= 6'd0;
	else if(start&wr)
		oew_con <= 6'd0;
	else if((con_w[1:0]==2'b11)&(con_div == 12'h1))
		oew_con <= oew_con + 1'b1;
	else
		oew_con <= oew_con;
end

always @ (posedge clk or posedge reset) 
begin
	if(reset)
		oer_con <= 6'd0;
	else if(start&(~wr))
		oer_con <= 6'd0;
	else if((con_r[1:0]==2'b11)&(con_div == 12'h1))
		oer_con <= oer_con + 1'b1;
	else
		oer_con <= oer_con;
end

always @ (posedge clk or posedge reset) 
begin
	if(reset) sio_e<=1'b1;
	else if((oew_con==6'd10)| (oew_con==6'd19)|(oew_con==6'd28)|(oew_con==6'd37)) sio_e<=1'b0;
	else if((oer_con==6'd10)| (oer_con==6'd19)|(oer_con==6'd28)|(oer_con==6'd39)) sio_e<=1'b0; 
	else if((oer_con>6'd39)&(oer_con<6'd48)) sio_e<=1'b0;
	else sio_e<=1'b1;
end

always @ (posedge clk or posedge reset) 
begin
	if(reset)
		sio_c_w <= 1'b1;
	else if(con_w<8'd6)
		sio_c_w <= 1'b1;
	else if(con_w>8'd152)
		sio_c_w <= 1'b1;
	else if((con_w[0]==1'b0)&(con_div == 12'h1))
		sio_c_w <= ~sio_c_w;
	else 
		sio_c_w <= sio_c_w;	
end 

always @ (posedge clk or posedge reset) 
begin
	if(reset)
		sio_c_r <= 1'b1;
	else if(con_r<8'd6)
		sio_c_r <= 1'b1;
	else if(con_r>8'd196)
		sio_c_r <= 1'b1;
	else if((con_r>8'd116)&(con_r<8'd122))
		sio_c_r <= 1'b1;
	else if((con_r[0]==1'b0)&(con_div == 12'h1))
		sio_c_r <= ~sio_c_r;
	else 
		sio_c_r <= sio_c_r;	
end



assign sio_c = wr ? sio_c_w : sio_c_r;
assign sio_d_temp = wr ? shiftw[39] : shiftr[50];
assign sio_d = sio_e ? sio_d_temp : 1'bz;

always @ (posedge clk) if((con_r==8'd161)&(con_div == 12'h1)) r_data[7]<=sio_d;
always @ (posedge clk) if((con_r==8'd165)&(con_div == 12'h1)) r_data[6]<=sio_d;
always @ (posedge clk) if((con_r==8'd169)&(con_div == 12'h1)) r_data[5]<=sio_d;
always @ (posedge clk) if((con_r==8'd173)&(con_div == 12'h1)) r_data[4]<=sio_d;
always @ (posedge clk) if((con_r==8'd177)&(con_div == 12'h1)) r_data[3]<=sio_d;
always @ (posedge clk) if((con_r==8'd181)&(con_div == 12'h1)) r_data[2]<=sio_d;
always @ (posedge clk) if((con_r==8'd185)&(con_div == 12'h1)) r_data[1]<=sio_d;
always @ (posedge clk) if((con_r==8'd189)&(con_div == 12'h1)) r_data[0]<=sio_d; 

always @ (posedge clk) if((con_r==8'd202)|(con_w==8'd158)) done<=1'b1; else done<=1'b0;

endmodule
