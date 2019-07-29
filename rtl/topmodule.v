//----------------------
//This module is the top module.
//raspberry pi <---> scom ----> command fifo ------> decode -------> sccb_control
//                   scom <---- wdata fifo <-------- decode 
//raspberry pi <---> spi  <---- camera data fifo <-- sdram_core	  
//                  decode ----> sdram_control ----> sdram_core
//camera --> camera data decode --->swdata fifo ---> sdram_core <-----> sdram
//Created by dong on 2019.4.28 
//----------------------

module topmodule
#
(
	parameter SDR_BA_WIDTH            =  2,
	parameter SDR_ROW_WIDTH           =  13,
	parameter SDR_COL_WIDTH           =  9,
	parameter SDR_DQ_WIDTH            =  16,
	parameter SDR_DQM_WIDTH           =  SDR_DQ_WIDTH/8,
	parameter APP_ADDR_WIDTH          =  SDR_BA_WIDTH + SDR_ROW_WIDTH + SDR_COL_WIDTH,
	parameter APP_BURST_WIDTH         =  9
)
(
	input wire nrst, //active Low
	input wire clk, //sys_clk 50Mhz
	
	input wire scom_rxd,
	output wire scom_txd,
	
	inout wire sio_d,
	output wire sio_c,
	
	input wire spi_mclk,
	output wire spi_miso,
	input wire spi_cs,
	
	input wire camera_mclk,
	input wire camera_mdata,
	
	output wire DRAM_CLK, //sdram clk
	output wire DRAM_CKE,           //clock enable
	output wire DRAM_CS_N,          //chip select
	output wire DRAM_RAS_N,         //row select
	output wire DRAM_CAS_N,         //colum select
	output wire DRAM_WE_N,          //write enable
	output wire [SDR_BA_WIDTH-1:0] DRAM_BA,            //bank address
	output wire [SDR_ROW_WIDTH-1:0] DRAM_ADDR,          //address
	output wire [SDR_DQM_WIDTH-1:0] DRAM_DQM,           //data mask
	inout wire [SDR_DQ_WIDTH-1: 0] DRAM_DQ,             //data
	
	output wire en_pin,
	output reg  led_sign,
	output wire frame_sign
	
);

wire reset;
wire clk_25;
wire clk_143;
wire clk_200;
wire clk_300;
wire wr_empty;
wire [7:0] wr_data;
wire wr_req;
wire c_wr;
wire [7:0] c_data;
wire [7:0] fw_data;
wire fw_req;
wire fc_req;
wire fc_empty;
wire [7:0] fc_q;
wire [6:0] sc_addr;
wire [15:0] sc_subaddr;
wire [7:0] sc_w_data;
wire [7:0] sc_r_data;
wire sc_wr;
wire sc_start;
wire sc_done;
wire [9:0] camera_dout;
wire camera_clk_out;
wire [9:0] wr_burst_data;
wire wr_burst_data_req;
wire wr_burst_req;
wire [9:0] rdusedw;
wire [APP_ADDR_WIDTH-1:0] wr_burst_addr;
wire wr_burst_finish;
wire rd_burst_req,sdram_rd_req,core_rd_req;
wire [APP_ADDR_WIDTH-1:0] rd_burst_addr,core_rd_addr,sdram_rd_addr;
wire [SDR_DQ_WIDTH-1:0] rd_burst_data;
wire rd_burst_data_valid;
wire rd_burst_finish;
wire spi_fifo_rd;
wire [9:0] spi_fifo_q;
wire spi_fifo_empty;
wire spi_fifo_full;
wire c_pulse;
wire camera_fifo_wrreq;
wire SDRAMFlag,mode;
wire A_sign;

assign en_pin = 1'b1;
assign reset = ~nrst;

clkgen clkgen_inst (
	.inclk0(clk),
	.c0(clk_25),
	.c1(clk_143),
	.c2(clk_200),
	.c3(clk_300)
	);

w_fifo w_fifo_inst 
(
	.aclr(reset),
	.clock(clk_25),
	.data(fw_data),
	.rdreq(wr_req),
	.wrreq(fw_req),
	.empty(wr_empty),
	.full(),
	.q(wr_data)
);
	
scom scom_inst
(
	.reset(reset), //active High
	.clk(clk_25),   //25MHz
	
	.scom_rxd(scom_rxd), //receive from raspberry pi
	.scom_txd(scom_txd), //send data to raspberry pi
	
	.wr_empty(wr_empty), //ask to write a data,connect to fifo empty
	.wr_data(wr_data), //connect to fifo_q
	.wr_req(wr_req), //connect to fifo_r_en
	
	.c_wr(c_wr), //connect to fifo wr_en, this fifo is command fifo and the decode speed will be more fast
	.c_data(c_data) // data read from raspberry pi
);

c_fifo c_fifo_inst 
(
	.aclr(reset),
	.clock(clk_25),
	.data(c_data),
	.rdreq(fc_req),
	.wrreq(c_wr),
	.empty(fc_empty),
	.full(),
	.q(fc_q)
);

decode decode_inst
(
	.reset(reset),
	.clk(clk_25),
	.fw_data(fw_data),
	.fw_req(fw_req),
	
	.fc_req(fc_req),
	.fc_empty(fc_empty),
	.fc_q(fc_q),
	
	.sc_addr(sc_addr),
	.sc_subaddr(sc_subaddr),
	.sc_w_data(sc_w_data),
	.sc_r_data(sc_r_data),
	.sc_wr(sc_wr),
	.sc_start(sc_start),
	.sc_done(sc_done),
	.c_pulse(c_pulse),
	.mode(mode)
	
);


sccb_control sccb_control_inst
(
	.clk(clk_25),               // 25Mhz
	.reset(reset),             // Reset signal (active-low)
	.clk_div(12'h040),    // Clock divider value to configure SDIO_C from system clock
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

spi spi_inst
(
	.clk(clk_200), //sysclk 200Mhz
	
	//connect to spi bus
	.mclk(spi_mclk),
	.miso(spi_miso),
	.cs(spi_cs),
	
	//connect to data fifo 
	.fifo_empty(spi_fifo_empty),
	.fifo_data({5'b00000,spi_fifo_q}),
	.fifo_rd(spi_fifo_rd)
);

spi_fifo spi_fifo_inst 
(
	.data(rd_burst_data[9:0]),
	.rdclk(clk_200),
	.rdreq(spi_fifo_rd),
	.wrclk(clk_143),
	.wrreq(rd_burst_data_valid&mode),
	.q(spi_fifo_q),
	.rdempty(spi_fifo_empty),
	.wrfull(spi_fifo_full)
);

assign core_rd_addr = mode ? sdram_rd_addr : rd_burst_addr;
assign core_rd_req = mode ? (sdram_rd_req&(~spi_fifo_full)) : rd_burst_req;

//assign core_rd_addr = sdram_rd_addr ;
//assign core_rd_req = sdram_rd_req&(~spi_fifo_full);

sdram_core sdram_core_inst
(
	.clk(clk_143),
	.rst(reset),                 //reset signal,high for reset
	//write
	.wr_burst_req(wr_burst_req),        //  write request
	.wr_burst_data({6'b000000,wr_burst_data}),       //  write data
	.wr_burst_len(9'd256),        //  write data length, ahead of wr_burst_req
	.wr_burst_addr(wr_burst_addr),       //  write base address of sdram write buffer
	.wr_burst_data_req(wr_burst_data_req),   //  wrtie data request, 1 clock ahead
	.wr_burst_finish(wr_burst_finish),     //  write data is end
	//read
	.rd_burst_req(core_rd_req),    //read request
	.rd_burst_len(9'd1),        //  read data length, ahead of rd_burst_req
	.rd_burst_addr(core_rd_addr),       //  read base address of sdram read buffer   //in
	.rd_burst_data(rd_burst_data),       //  read data to internal
	.rd_burst_data_valid(rd_burst_data_valid), //  read data enable (valid)
	.rd_burst_finish(rd_burst_finish),     //  read data is end
	//sdram
	.sdram_cke(DRAM_CKE),           //clock enable
	.sdram_cs_n(DRAM_CS_N),          //chip select
	.sdram_ras_n(DRAM_RAS_N),         //row select
	.sdram_cas_n(DRAM_CAS_N),         //colum select
	.sdram_we_n(DRAM_WE_N),          //write enable
	.sdram_ba(DRAM_BA),            //bank address
	.sdram_addr(DRAM_ADDR),          //address
	.sdram_dqm(DRAM_DQM),           //data mask
	.sdram_dq(DRAM_DQ)             //data
);
assign DRAM_CLK = clk_143;

sdram_control sdram_control_inst
(
	.clk(clk_143),
	.reset(reset),                 //reset signal,high for reset
	
	.A_sign(A_sign),
    .c_pulse(c_pulse),
	
	.SDRAMFlag(SDRAMFlag),
	
	.wr_burst_addr(wr_burst_addr),
	.wr_burst_finish(wr_burst_finish),
	
	.rd_burst_req(sdram_rd_req),    //out  change
	.rd_burst_addr(sdram_rd_addr),       // out
	.rd_burst_finish(rd_burst_finish)
	
);

camera_decode camera_decode_inst
(
	.clk(clk_143),
	.reset(reset),                 //reset signal,high for reset
	.clk_200(clk_300),
	.mclk(camera_mclk),
	.mdata(camera_mdata),
	
	.dout(camera_dout),
	.frame_sign(frame_sign),
   .A_sign(A_sign),
	.led_sign(led_sign),
   .camera_fifo_wrreq(camera_fifo_wrreq) 

	
);

camera_fifo camera_fifo_inst   // have problem
(
	.aclr(A_sign),
	.data(camera_dout),
	.rdclk(clk_143),
	.rdreq(wr_burst_data_req),
	.wrclk(clk_300),
	.wrreq(camera_fifo_wrreq),
	.q(wr_burst_data),
	.rdusedw(rdusedw)
);

camera_top camera_top_inst(
	.reset(~reset),											 //The low active
	.clk(clk_143),                                //100Mhz
	.SDRAMFlag(SDRAMFlag),
	.rd_burst_finish(rd_burst_finish),            // input read data is end 	

	.rd_burst_data(rd_burst_data),
	.rd_burst_req(rd_burst_req),						// output read request
	.rd_burst_addr(rd_burst_addr),						// address  out 
	.rd_burst_data_valid(rd_burst_data_valid),
	.Angle(),
	.code()
);

assign wr_burst_req = rdusedw[8];


endmodule
