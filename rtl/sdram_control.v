module sdram_control
(
	input wire 			 clk,
	input wire			 reset,                 //reset signal,high for reset
	input wire 			 A_sign,
	output wire [23:0] wr_burst_addr,  // [18:0] -- a frame [19:23]  -- the last frame
	input wire 			 wr_burst_finish,
	
	output reg 		  	rd_burst_req,
	output reg [23:0] rd_burst_addr,
	input wire 			rd_burst_finish,
	output reg        SDRAMFlag,
	
   input wire 			c_pulse
        
    
);
//camera_fifo_wrreq rd_burst_req 
reg [10:0] addr_L;
reg [4:0]  addr_H;

reg A_sign_dd,A_sign_d;

assign wr_burst_addr = {addr_H,addr_L,8'h00};

always @ (posedge clk ) begin  A_sign_d <= A_sign; A_sign_dd <= A_sign_d; end

// addr_L
always @ (posedge clk or posedge reset)
begin
	if (reset)
		addr_L <= 11'h000000;
	else if((~A_sign_dd)&A_sign_d)
		addr_L <= 11'h000000;
	else if(wr_burst_finish)
		addr_L <= addr_L + 1'b1;
	else
		addr_L <= addr_L;	
end
// addr_H  --  Fang change
always @ (posedge clk or posedge reset)
begin
	if (reset)
		 addr_H <= 5'b00000;
	else if((A_sign_dd)&~A_sign_d)
		 addr_H <= addr_H + 1'b1;
	else 
		 addr_H <= addr_H;
end 
 

always @ (posedge clk or posedge reset)
begin
	if (reset)
		SDRAMFlag <= 1'b0;
	else if((~A_sign_dd)&A_sign_d)
		SDRAMFlag <= 1'b1;
	else
		SDRAMFlag <= 1'b0;
end


always @ (posedge clk or posedge reset)
begin
	if (reset)
		begin rd_burst_addr <= 24'h000000; rd_burst_req<=1'b0; end 
	else if(c_pulse)
		begin rd_burst_addr <= 24'h000000; rd_burst_req<=1'b1; end 
	else if(rd_burst_addr==24'h10C8DF)
		begin rd_burst_addr <= 24'h000000; rd_burst_req<=1'b0; end 
	else if(rd_burst_finish)
		begin rd_burst_addr <= rd_burst_addr + 1'b1; rd_burst_req<=rd_burst_req; end
		//begin rd_burst_addr <= rd_burst_addr; rd_burst_req<=1'b0; end
	else 
		begin rd_burst_addr <= rd_burst_addr; rd_burst_req<=rd_burst_req; end//
end


		
endmodule

