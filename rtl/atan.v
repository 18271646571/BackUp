module atan(
	input wire clk,
	input wire rst,
	input wire signed [23:0] din_a,
	input wire signed [23:0] din_b,
	output reg signed [23:0] angle_o,
	input start
	);
	
	
	reg			[03:0]	count;
	reg	signed	[23:0]	dat_a;
	reg	signed	[23:0]	dat_b;
	reg	signed	[23:0]	angle;
	
	wire	signed	[23:0]	dat_a_new;
	wire	signed	[23:0]	dat_b_new;
	wire	signed	[23:0]	angle_new;
	
	wire	signed	[23:0]	angle_mem[0:15];
	
	
	assign angle_mem[0]  = 24'd11520;
	assign angle_mem[1]  = 24'd6801;
	assign angle_mem[2]  = 24'd3593;
	assign angle_mem[3]  = 24'd1824;
	assign angle_mem[4]  = 24'd916;
	assign angle_mem[5]  = 24'd458;
	assign angle_mem[6]  = 24'd229;
	assign angle_mem[7]  = 24'd115;
	assign angle_mem[8]  = 24'd57;
	assign angle_mem[9]  = 24'd29;
	assign angle_mem[10] = 24'd14;
	assign angle_mem[11] = 24'd7;
	assign angle_mem[12] = 24'd4;
	assign angle_mem[13] = 24'd2;
	assign angle_mem[14] = 24'd1;
	assign angle_mem[15] = 24'd0;
	
	
	assign dat_a_new = dat_a >>> count;
	assign dat_b_new = dat_b >>> count;
	assign angle_new = angle_mem[count];
	
	
	always@(posedge clk or negedge rst)
	begin
		if(!rst)
			count <= 4'd0;
		else if(start)
			count <= 4'd15;
		else
			count <= count + 4'd1;
		
	end
	
	always@(posedge clk)
	begin
		if(count == 4'd15)
		begin
			angle <= 24'd0;
			dat_a <= din_a;
			dat_b <= din_b;
			angle_o <= angle;
		end
		else 
		begin
			if(dat_a[23] == dat_b[23])
			begin
				dat_a <= dat_a + dat_b_new;
				dat_b <= dat_b - dat_a_new;
				angle <= angle + angle_new;
			end
			else begin
				dat_a <= dat_a - dat_b_new;
				dat_b <= dat_b + dat_a_new;
				angle <= angle - angle_new;
			end
		end
	end
	
endmodule