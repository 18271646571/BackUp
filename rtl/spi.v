//----------------------
//This module is a SPI for data transfer between FPGA and raspberry pi.
//only raspberry pi read data from FPGA, FIFO use first word Through MODE
//CPOL=0,CPHA=1, read 16bit data(15bitdata and fifo_empty sign) to raspberry pi
//speed : 125MHZ
//Created by dong on 2019.4.26 
//----------------------
module spi
(
	input wire clk, //sysclk 200Mhz
	
	//connect to spi bus
	input wire mclk,
	output wire miso,
	input wire cs,
	
	//connect to data fifo 
	input wire fifo_empty,
	input wire [14:0] fifo_data,
	output reg fifo_rd
);

reg cs_d1,cs_d2;
reg load,load_d;
reg [16:0] dout;

always @ (posedge clk)
begin
	cs_d1 <= cs;
	cs_d2 <= cs_d1;
	load<= (~cs_d1)&cs_d2;
	load_d<= load;
	fifo_rd <= load_d;
end


always @ (posedge mclk or posedge load)
begin
	if(load)
		dout <= {1'b0,fifo_empty,fifo_data};
	else
		dout <= {dout[15:0],1'b0};
end

assign miso = dout[16];

endmodule