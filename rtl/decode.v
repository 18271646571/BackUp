module decode
(
	input wire reset,
	input wire clk,
	output wire [7:0] fw_data,
	output reg fw_req,
	
	output wire fc_req,
	input wire fc_empty,
	input wire [7:0] fc_q,
	
	output wire [6:0] sc_addr,
	output reg [15:0] sc_subaddr,
	output reg [7:0] sc_w_data,
	input wire [7:0] sc_r_data,
	output reg sc_wr,
	output reg sc_start,
	input wire sc_done,
	
	output reg c_pulse,
	output reg mode
);

reg fc_req_d;

assign fc_req = ~fc_empty;
always @(posedge clk) fc_req_d <= fc_req;

//decode
assign fw_data = sc_r_data;
assign sc_addr = 7'b1100000;

always @(posedge clk) if(fc_req_d&(fc_q[7:4]==4'h1)) sc_start<=1'b1; else sc_start<=1'b0;
always @(posedge clk) if(fc_req_d&(fc_q[7:4]==4'h2)) fw_req<=1'b1; else fw_req<=1'b0;
always @(posedge clk) if(fc_req_d&(fc_q[7:4]==4'h3)) sc_wr<=fc_q[0];

always @(posedge clk) if(fc_req_d&(fc_q[7:4]==4'h4)) sc_subaddr[3:0]<=fc_q[3:0]; 
always @(posedge clk) if(fc_req_d&(fc_q[7:4]==4'h5)) sc_subaddr[7:4]<=fc_q[3:0]; 
always @(posedge clk) if(fc_req_d&(fc_q[7:4]==4'h6)) sc_subaddr[11:8]<=fc_q[3:0]; 
always @(posedge clk) if(fc_req_d&(fc_q[7:4]==4'h7)) sc_subaddr[15:12]<=fc_q[3:0]; 

always @(posedge clk) if(fc_req_d&(fc_q[7:4]==4'h8)) sc_w_data[3:0]<=fc_q[3:0]; 
always @(posedge clk) if(fc_req_d&(fc_q[7:4]==4'h9)) sc_w_data[7:4]<=fc_q[3:0]; 

always @(posedge clk) if(fc_req_d&(fc_q[7:4]==4'ha)) c_pulse<=1'b1; else c_pulse<=1'b0; 

always @(posedge clk or posedge reset) 
begin
	if(reset)
		mode<=1'b0;
	else if(fc_req_d&(fc_q[7:4]==4'hb)) mode<=fc_q[0]; 
	else mode<=mode;
end
 
endmodule