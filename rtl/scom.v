//----------------------
//This module is a SCOM for communicate between FPGA and raspberry pi.
//baurdrate : 1MHZ, 1statr-8bit-1stop
//Created by dong on 2019.4.26 
//----------------------
module scom
(
	input wire reset, //active High
	input wire clk,   //25MHz
	
	input wire scom_rxd, //receive from raspberry pi
	output reg scom_txd, //send data to raspberry pi
	
	input wire wr_empty, //ask to write a data,connect to fifo empty
	input wire [7:0] wr_data, //connect to fifo_q
	output reg wr_req, //connect to fifo_r_en
	
	output reg c_wr, //connect to fifo wr_en, this fifo is command fifo and the decode speed will be more fast
	output reg [7:0] c_data // data read from raspberry pi
);

reg [7:0] ucon,tcon;

// receive data
always @ (posedge clk or posedge reset)
begin
	if(reset)
		ucon <= 8'd0;
	else
		if(ucon == 8'd0)
			if(scom_rxd==1'b0)
				ucon <= 8'd1;
			else 
				ucon <= 8'd0;
		else
			if(ucon == 8'd245 ) 
				ucon <= 8'd0;
			else 
				ucon <= ucon + 1'b1;
end

always @ (posedge clk) if(ucon == 8'd37) c_data[0]<=scom_rxd; else c_data[0]<=c_data[0];
always @ (posedge clk) if(ucon == 8'd62) c_data[1]<=scom_rxd; else c_data[1]<=c_data[1];
always @ (posedge clk) if(ucon == 8'd87) c_data[2]<=scom_rxd; else c_data[2]<=c_data[2];
always @ (posedge clk) if(ucon == 8'd112) c_data[3]<=scom_rxd; else c_data[3]<=c_data[3];
always @ (posedge clk) if(ucon == 8'd137) c_data[4]<=scom_rxd; else c_data[4]<=c_data[4];
always @ (posedge clk) if(ucon == 8'd162) c_data[5]<=scom_rxd; else c_data[5]<=c_data[5];
always @ (posedge clk) if(ucon == 8'd187) c_data[6]<=scom_rxd; else c_data[6]<=c_data[6];
always @ (posedge clk) if(ucon == 8'd212) c_data[7]<=scom_rxd; else c_data[7]<=c_data[7];
always @ (posedge clk) if(ucon == 8'd237) c_wr<=1'b1; else c_wr<=1'b0;	

// send data 
always @ (posedge clk or posedge reset)
begin
	if(reset)
		tcon <= 8'd0;
	else
		if(tcon == 8'd0)
			if(~wr_empty)
				tcon <= 8'd1;
			else 
				tcon <= 8'd0;
		else
			if(tcon == 8'd250 ) 
				tcon <= 8'd0;
			else 
				tcon <= tcon + 1'b1;
end

always @ (posedge clk) if(tcon == 8'd1) wr_req <= 1'b1; else wr_req <= 1'b0;

always @ (posedge clk) 
begin
	if(tcon == 8'd0) 
		scom_txd <= 1'b1; 
	else if (tcon == 8'd1)
		scom_txd <= 1'b0;
	else if (tcon == 8'd25)
		scom_txd <= wr_data[0];
	else if (tcon == 8'd50)
		scom_txd <= wr_data[1];
	else if (tcon == 8'd75)
		scom_txd <= wr_data[2];
	else if (tcon == 8'd100)
		scom_txd <= wr_data[3];
	else if (tcon == 8'd125)
		scom_txd <= wr_data[4];
	else if (tcon == 8'd150)
		scom_txd <= wr_data[5];
	else if (tcon == 8'd175)
		scom_txd <= wr_data[6];
	else if (tcon == 8'd200)
		scom_txd <= wr_data[7];
	else if (tcon == 8'd225)
		scom_txd <= 1'b1;
	else 
		scom_txd <= scom_txd;
end


endmodule