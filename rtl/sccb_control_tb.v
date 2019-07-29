`timescale 1ns/1ps
module sccb_control_tb;

reg clk;
reg reset;

wire sio_d;
wire sio_c;

reg [6:0] sc_addr;
reg [15:0] sc_subaddr;
reg [7:0] sc_w_data;
wire [7:0] sc_r_data;
reg sc_wr;
reg sc_start;
wire sc_done;

initial 
begin
	sc_addr = 6'b011100;
	sc_subaddr = 16'h1234;
	sc_w_data = 8'haa;
	sc_wr = 1'b1;
	sc_start = 1'b0;
	reset =1'b0;
	clk = 1'b0;
	#100
	reset = 1'b1;
	#100
	reset = 1'b0;
	#100
	sc_start = 1'b1;
	#100
	sc_start = 1'b0;
	
end

always  
begin
#5 clk <= ~clk; 
end
 
sccb_control sccb_control_inst
(
	.clk(clk),               // 25Mhz
	.reset(reset),             // Reset signal (active-low)
	.clk_div(12'h100),    // Clock divider value to configure SDIO_C from system clock
	.sio_d(sio_d),            // SCCB data (tri-state)
	.sio_c(sio_c),            // SCCB clock
	.addr(sc_addr),        // Address of device
	.subaddr(sc_subaddr),     // Sub-Address (Register) to write to
	.w_data(sc_w_data),      // Data to write to device
	.r_data(sc_r_data), // Data read from device
	.wr(sc_wr),           // 1: write ,0 read
	.start(sc_start),
	.done(sc_done)
);

endmodule