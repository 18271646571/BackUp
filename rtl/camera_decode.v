//----------------------
//This module is for the camera data decode
//Created by dong on 2019.5.5 
//----------------------
module camera_decode
(
	input wire clk,
	input wire reset,
	
	input wire clk_200,  //300M
	input wire mclk,    // 150M  
	input wire mdata,
	
	output reg [9:0] dout,
	output reg frame_sign,
   output reg A_sign,
	output reg led_sign, 
    
    // Fang  change  //
     
    output reg camera_fifo_wrreq    // Flag sign
    //***************//
		
);

reg [41:0] datap;
wire [1:0] ddio_out;
reg [2:0] con;
reg sign;
reg [19:0] con_f;



// Fang change //
reg [19:0] counter;

wire [1:0] ddio_q;
wire ddio_empty;
wire ddio_rdreq;
reg ddio_rdreq_d;

//************//
ddio ddio_inst(
	.datain(mdata),
	.inclock(mclk),
	.dataout_h(ddio_out[0]),
	.dataout_l(ddio_out[1])
	);
	
assign ddio_rdreq = ~ddio_empty;
always @(posedge clk_200) ddio_rdreq_d <= ddio_rdreq;
decode_fifo decode_fifo_inst (
	.data(ddio_out),
	.rdclk(clk_200),
	.rdreq(ddio_rdreq),
	.wrclk(mclk),
	.wrreq(1'b1),
	.q(ddio_q),
	.rdempty(ddio_empty)
	);
	
always @(posedge clk_200)
begin
	if(ddio_rdreq_d) datap <= {datap[39:0],ddio_q};
end
	
	
always @(posedge clk_200)
begin
	if(ddio_rdreq_d)
		begin
		if (datap[40:1]==40'b1111111111_0000000000_0000000000_1000000000) 
			 sign<= 1'b1;
		else 
			sign<= 1'b0;
		end
	else
		sign<=sign;
end


always @(posedge clk_200)
begin
	if(ddio_rdreq_d)
		begin
		if(sign)
			con <= 3'd2;
		else if(con==3'd4)
			con <= 3'd0;
		else 
			con <= con + 1'b1;
		end
	else
		con <= con;
end


always @(posedge clk_200)
begin
	if((con==3'd0)&ddio_rdreq_d)
		dout <= datap[40:31];
	else 
		dout <= dout;
end

always @(posedge clk_200) 
begin
	if(ddio_rdreq_d)
		begin if(sign) con_f <= 20'h00000; else con_f <= con_f + 1'b1; end
	else con_f <= con_f;
end

always @(posedge clk_200) if(con_f[19:4] == 16'h0200) frame_sign <= 1'b1; else frame_sign <= 1'b0;

always @(posedge clk_200) if ((con_f >= 20'd69192)&(con_f <= 20'd89192))  led_sign <= 1'b1; else led_sign <= 1'b0;

// Fang change //
always @(posedge clk_200) if (frame_sign) A_sign <= 1'b1; else if (sign) A_sign <= 1'b0; else A_sign <= A_sign;

always @(posedge clk_200 or posedge reset)
begin
    if (reset)
        counter <= 20'd0;
	 else
		begin 
		if(sign&A_sign)
			counter <= 1'b1;
		else if(camera_fifo_wrreq)
			begin
			if(counter == 20'h71200)     // 965*480*5--1810*480*5
				counter <= 20'd0;
			else if(counter != 20'h00000 )
				counter <= counter +1'b1;    
			else
				counter <= 20'd0; 
			end
		else
			counter <= counter;
		end
end



always @(posedge clk_200 or posedge reset)
begin
    if (reset)
        camera_fifo_wrreq <= 1'b0;
    else if (((con == 3'd2)&ddio_rdreq_d)&(counter != 20'h00000 ))
        camera_fifo_wrreq <= 1'b1;
    else
        camera_fifo_wrreq <= 1'b0;
end

//*************//
endmodule
