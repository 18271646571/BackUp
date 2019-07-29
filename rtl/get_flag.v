module get_flag(
	input clk,//100MHz
	input rst_n,//reset active negedge
	input start,// active high pulse
	input[9:0] ctr_coords_x, //center coords 
	input[9:0] ctr_coords_y,
	//request a value of a point
	input pt_valid, // point value valid, active high pulse
	input pt_value, // point value
//	output reg[8:0] pt_addr,
	output reg[9:0] pt_coords_x, // point coords
	output reg[9:0] pt_coords_y,
	output reg pt_req, // point value request, active high pulse
	//report the flag point
	output reg[9:0] flag_coords_x, // flag coords
	output reg[9:0] flag_coords_y, // flag coords
	output reg complete //active high pulse
	
);


// 模块内部用坐标x,y表示点,点的地址映射放在Top层

reg[9:0] x_cnt,y_cnt;
reg[31:0] sum_x, sum_y;
reg[31:0] pt_cnt;
reg[9:0] pt_addr;
parameter ROM_DEPTH = 10'd535;
wire[9:0] mem_x,mem_y;
wire[31:0] quotient_x,quotient_y;
wire[9:0] remainder_x,remainder_y;
reg[9:0] orien_coords_x, orien_coords_y, offset_coords_x, offset_coords_y;
//state machine
reg[11:0] current_state,next_state;
parameter 
	IDLE 						= 12'b0000_0000_0001, // idle
	GET_PT_ROM 				= 12'b0000_0000_0010, // get point coords and send them to top level
	GET_PT_VALUE 			= 12'b0000_0000_0100, // get a point value
	GET_WHITE 				= 12'b0000_0000_1000, // identify whether the point is white or black
	GET_WAIT 				= 12'b0000_0001_0000,
	GET_WHITE_CTR 			= 12'b0000_0010_0000, // calculate the center point of the white points
	GET_GRAVITY_CENTER_1 = 12'b0000_0100_0000, // initialize the variable
	GET_GRAVITY_CENTER_2 = 12'b0000_1000_0000, // get point coords and send them to top level
	GET_GRAVITY_CENTER_3 = 12'b0001_0000_0000, // get a point value
	GET_GRAVITY_CENTER_4 = 12'b0010_0000_0000, // identify whether the point is white or black
	GET_GRAVITY_CENTER_5 = 12'b0100_0000_0000, // calculate the center of gravity
	REPORT 					= 12'b1000_0000_0000; // report the center of flag to top level

divider divider_inst_x
( 
	.a(sum_x),
	.b(pt_cnt),
	.quotient(quotient_x),
	.remainder(remainder_x)
); 
divider divider_inst_y
( 
	.a(sum_y),
	.b(pt_cnt),
	.quotient(quotient_y),
	.remainder(remainder_y)
); 

rom_x	rom_x_inst (
	.address ( pt_addr ),
	.clock ( clk ),
	.q ( mem_x )
);
rom_y	rom_y_inst (
	.address ( pt_addr ),
	.clock ( clk ),
	.q ( mem_y )
);
// first phase
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		current_state <= IDLE;
	else 
		current_state <= next_state;
end
// second phase
always@(current_state, start, pt_valid, pt_addr, x_cnt, y_cnt)
begin
	case(current_state)
		IDLE : if(start==1'b1) next_state <= GET_PT_ROM; else next_state <= current_state;
		GET_PT_ROM : next_state <= GET_PT_VALUE;
		GET_PT_VALUE : if(pt_valid == 1'b1)next_state <= GET_WHITE;
					else next_state <= current_state;
		GET_WHITE: if(pt_addr == ROM_DEPTH) next_state <= GET_WAIT; 
					else next_state <=GET_PT_ROM;
		GET_WAIT: next_state <= GET_WHITE_CTR;
		GET_WHITE_CTR: next_state <= GET_GRAVITY_CENTER_1;
		GET_GRAVITY_CENTER_1: next_state <= GET_GRAVITY_CENTER_2;
		GET_GRAVITY_CENTER_2: next_state <= GET_GRAVITY_CENTER_3;
		GET_GRAVITY_CENTER_3: if(pt_valid == 1'b1)next_state <= GET_GRAVITY_CENTER_4;
					else next_state <= current_state;
		GET_GRAVITY_CENTER_4: if(x_cnt == 10'd15 && y_cnt == 10'd15) next_state <= GET_GRAVITY_CENTER_5; 
					else next_state <=GET_GRAVITY_CENTER_2;
		GET_GRAVITY_CENTER_5: next_state <= REPORT;
		REPORT : next_state <= IDLE;
		default : next_state <= IDLE;
	endcase
end
// third phase
always@(posedge clk)
begin
	case(current_state)
		IDLE : 
				begin 
					pt_req <= 1'b0; complete <= 1'b0; 
					sum_x <= 32'd0;
					sum_y <= 32'd0;
					pt_cnt <= 32'd0;
				end
		GET_PT_ROM : 
				begin 
					sum_x <= sum_x;
					sum_y <= sum_y;
					pt_cnt <= pt_cnt;
					pt_req <= 1'b1; 
					pt_coords_x <= ctr_coords_x + mem_x; 
					pt_coords_y <= ctr_coords_y + mem_y; 
					complete <= 1'b0; 
				end
		GET_PT_VALUE : 
				begin 
					sum_x <= sum_x;
					sum_y <= sum_y;
					pt_cnt <= pt_cnt;
					pt_req <= 1'b1; 
					complete <= 1'b0; 
				end
		GET_WHITE : 
				begin 
					pt_req <= 1'b0; complete <= 1'b0;
					if(pt_value == 1'b0)
						begin
							sum_x <= sum_x + pt_coords_x;
							sum_y <= sum_y + pt_coords_y;
							pt_cnt <= pt_cnt + 1'b1;
						end
					else
						begin
							sum_x <= sum_x;
							sum_y <= sum_y;
							pt_cnt <= pt_cnt;
						end  
				end
		GET_WAIT : 
				begin 
					sum_x <= sum_x;
					sum_y <= sum_y;
					pt_cnt <= pt_cnt;
					pt_req <= 1'b0; 
					complete <= 1'b0; 
				end
		GET_WHITE_CTR : 
				begin 
					pt_req <= 1'b0; 
					complete <= 1'b0; 
					orien_coords_x <= quotient_x[9:0]; 
					orien_coords_y <= quotient_y[9:0];
				end
		GET_GRAVITY_CENTER_1:
				begin
					sum_x <= 32'd0;
					sum_y <= 32'd0;
					pt_cnt <= 32'd0;
					offset_coords_x <= orien_coords_x + 10'd1016; //offset_coords_x <= orien_coords_x - 5;
					offset_coords_y <= orien_coords_y + 10'd1016;
				end
		GET_GRAVITY_CENTER_2:
				begin
					pt_req <= 1'b1; 
					pt_coords_x <= offset_coords_x + x_cnt; 
					pt_coords_y <= offset_coords_y + y_cnt; 
					complete <= 1'b0; 
				end
		GET_GRAVITY_CENTER_3: begin pt_req <= 1'b1; complete <= 1'b0; end
		GET_GRAVITY_CENTER_4:
				begin 
					pt_req <= 1'b0; complete <= 1'b0;
					if(pt_value == 1'b1)
						begin
							sum_x <= sum_x + pt_coords_x;
							sum_y <= sum_y + pt_coords_y;
							pt_cnt <= pt_cnt + 1'b1;
						end
					else
						begin
							sum_x <= sum_x;
							sum_y <= sum_y;
							pt_cnt <= pt_cnt;
						end  
				end
		GET_GRAVITY_CENTER_5: 
				begin 
					pt_req <= 1'b0; 
					complete <= 1'b0; 
					flag_coords_x <= quotient_x; 
					flag_coords_y <= quotient_y;
				end
		REPORT : begin pt_req <= 1'b0; complete <= 1'b1; end
		default: begin pt_req <= 1'b0; complete <= 1'b0; end
	endcase
end
// 获取圆周上的白点
always@(posedge clk)
begin
	if(current_state==GET_WHITE)
		begin
			if(pt_addr == ROM_DEPTH)
				begin pt_addr <= 9'd0; end
			else
				pt_addr <= pt_addr + 1'b1;
		end
	else if(current_state == GET_PT_ROM || current_state == GET_PT_VALUE)
		begin
			pt_addr <= pt_addr;
		end
	else
		pt_addr <= 9'd0;
end
// 获取重心
always@(posedge clk)
begin
	if(current_state==GET_GRAVITY_CENTER_4)
		begin
			if(x_cnt == 10'd15 && y_cnt == 10'd15)
				begin x_cnt <= 10'd0; y_cnt <= 10'd0; end
			else if(x_cnt == 10'd15)
				begin x_cnt <= 10'd0; y_cnt <= y_cnt + 1'b1; end
			else
				begin x_cnt <= x_cnt + 1'b1;y_cnt <= y_cnt; end
		end
	else if(current_state==GET_GRAVITY_CENTER_2 || current_state==GET_GRAVITY_CENTER_3 || current_state==GET_GRAVITY_CENTER_5 )
		begin x_cnt <= x_cnt; y_cnt <= y_cnt; end
	else
		begin x_cnt <= 10'd0; y_cnt <= 10'd0; end
end
endmodule
/*
// 模块内部用坐标x,y表示点,点的地址映射放在Top层

reg[9:0] x_cnt,y_cnt;
reg[15:0] sum_x, sum_y;
reg[15:0] pt_cnt;
reg[8:0]  pt_addr;
wire[9:0] mem_x,mem_y;
wire[9:0] quotient_x,quotient_y;
wire[9:0] remainder_x,remainder_y;
reg[9:0] orien_coords_x, orien_coords_y, offset_coords_x, offset_coords_y;
//state machine
reg[11:0] current_state,next_state;
parameter 
	IDLE = 12'b0000_0000_0001, // idle
	GET_PT_ROM = 12'b0000_0000_0010, // get point coords and send them to top level
	GET_PT_VALUE = 12'b0000_0000_0100, // get a point value
	GET_WHITE = 12'b0000_0000_1000, // identify whether the point is white or black
	GET_WHITE_CTR = 12'b0000_0001_0000, // calculate the center point of the white points
	GET_GRAVITY_CENTER_1 = 12'b0000_0100_0000, // initialize the variable
	GET_GRAVITY_CENTER_2 = 12'b0000_1000_0000, // get point coords and send them to top level
	GET_GRAVITY_CENTER_3 = 12'b0001_0000_0000, // get a point value
	GET_GRAVITY_CENTER_4 = 12'b0010_0000_0000, // identify whether the point is white or black
	GET_GRAVITY_CENTER_5 = 12'b0100_0000_0000, // calculate the center of gravity
	REPORT = 12'b1000_0000_0000; // report the center of flag to top level

divider divider_inst_x
( 
	.a(sum_x),
	.b(pt_cnt),
	.quotient(quotient_x),
	.remainder(remainder_x)
); 
divider divider_inst_y
( 
	.a(sum_y),
	.b(pt_cnt),
	.quotient(quotient_y),
	.remainder(remainder_y)
); 

rom_x	rom_x_inst (
	.address ( pt_addr ),
	.clock ( clk ),
	.q ( mem_x )
);
rom_y	rom_y_inst (
	.address ( pt_addr ),
	.clock ( clk ),
	.q ( mem_y )
);
// first phase
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		current_state <= IDLE;
	else 
		current_state <= next_state;
end
// second phase
always@(current_state, start, pt_valid, pt_addr)
begin
	case(current_state)
		IDLE : if(start==1'b1) next_state <= GET_PT_ROM; else next_state <= current_state;
		GET_PT_ROM : next_state <= GET_PT_VALUE;
		GET_PT_VALUE : if(pt_valid == 1'b1)next_state <= GET_WHITE;
					else next_state <= current_state;
      GET_WHITE: if(pt_addr == 9'd396) next_state <= GET_WHITE_CTR; 
					else next_state <=GET_PT_ROM;
      GET_WHITE_CTR: next_state <= GET_GRAVITY_CENTER_1;
		GET_GRAVITY_CENTER_1: next_state <= GET_GRAVITY_CENTER_2;
		GET_GRAVITY_CENTER_2: next_state <= GET_GRAVITY_CENTER_3;
		GET_GRAVITY_CENTER_3: if(pt_valid == 1'b1)next_state <= GET_GRAVITY_CENTER_4;
					else next_state <= current_state;
		GET_GRAVITY_CENTER_4: if(x_cnt == 10'd9 && y_cnt == 10'd9) next_state <= GET_GRAVITY_CENTER_5; 
					else next_state <=GET_GRAVITY_CENTER_2;
		GET_GRAVITY_CENTER_5: next_state <= REPORT;
      REPORT : next_state <= IDLE;
		default : next_state <= IDLE;
	endcase
end
// third phase
always@(posedge clk)
begin
	case(current_state)
		IDLE : 
				begin 
					pt_req <= 1'b0; complete <= 1'b0; 
					sum_x <= 16'd0;
					sum_y <= 16'd0;
					pt_cnt <= 16'd0;
				end
		GET_PT_ROM : 
				begin 
					sum_x <= sum_x;
					sum_y <= sum_y;
					pt_cnt <= pt_cnt;
					pt_req <= 1'b1; 
					pt_coords_x <= ctr_coords_x + mem_x; 
					pt_coords_y <= ctr_coords_y + mem_y; 
					complete <= 1'b0; 
				end
		GET_PT_VALUE : 
				begin 
					sum_x <= sum_x;
					sum_y <= sum_y;
					pt_cnt <= pt_cnt;
					pt_req <= 1'b1;               //change 
					complete <= 1'b0; 
				end
		GET_WHITE : 
				begin 
					pt_req <= 1'b0; complete <= 1'b0;
					if(pt_value == 1'b1)
						begin
							sum_x <= sum_x + pt_coords_x;
							sum_y <= sum_y + pt_coords_y;
							pt_cnt <= pt_cnt + 1'b1;
						end
					else
						begin
							sum_x <= sum_x;
							sum_y <= sum_y;
							pt_cnt <= pt_cnt;
						end  
				end
		GET_WHITE_CTR : 
				begin 
					pt_req <= 1'b0; 
					complete <= 1'b0; 
					orien_coords_x <= quotient_x; 
					orien_coords_y <= quotient_y;
				end
		GET_GRAVITY_CENTER_1:
				begin
					sum_x <= 16'd0;
					sum_y <= 16'd0;
					pt_cnt <= 16'd0;
					offset_coords_x <= orien_coords_x + 10'd1019; //offset_coords_x <= orien_coords_x - 5;
					offset_coords_y <= orien_coords_y + 10'd1019;
				end
		GET_GRAVITY_CENTER_2:
				begin
					pt_req <= 1'b1; 
					pt_coords_x <= offset_coords_x + x_cnt; 
					pt_coords_y <= offset_coords_y + y_cnt; 
					complete <= 1'b0; 
				end
		GET_GRAVITY_CENTER_3: begin pt_req <= 1'b1; complete <= 1'b0; end  //change fang
		GET_GRAVITY_CENTER_4:
				begin 
					pt_req <= 1'b0; complete <= 1'b0;
					if(pt_value == 1'b0)
						begin
							sum_x <= sum_x + pt_coords_x;
							sum_y <= sum_y + pt_coords_y;
							pt_cnt <= pt_cnt + 1'b1;
						end
					else
						begin
							sum_x <= sum_x;
							sum_y <= sum_y;
							pt_cnt <= pt_cnt;
						end  
				end
		GET_GRAVITY_CENTER_5: 
				begin 
					pt_req <= 1'b0; 
					complete <= 1'b0; 
					flag_coords_x <= quotient_x; 
					flag_coords_y <= quotient_y;
				end
		REPORT : begin pt_req <= 1'b0; complete <= 1'b1; end
		default: begin pt_req <= 1'b0; complete <= 1'b0; end
	endcase
end
// 获取圆周上的白点
always@(posedge clk)
begin
	if(current_state==GET_WHITE)
		begin
			if(pt_addr == 9'd396)
				begin pt_addr <= 9'd0; end
			else
				pt_addr <= pt_addr + 1'b1;
		end
	else if(current_state == GET_PT_ROM || current_state == GET_PT_VALUE)
		begin
			pt_addr <= pt_addr;
		end
	else
		pt_addr <= 9'd0;
end
// 获取重心
always@(posedge clk)
begin
	if(current_state==GET_GRAVITY_CENTER_4)
		begin
			if(x_cnt == 10'd9 && y_cnt == 10'd9)
				begin x_cnt <= 10'd0; y_cnt <= 10'd0; end
			else if(x_cnt == 10'd9)
				begin x_cnt <= 10'd0; y_cnt <= y_cnt + 1'b1; end
			else
				begin x_cnt <= x_cnt + 1'b1;y_cnt <= y_cnt; end
		end
	else if(current_state==GET_GRAVITY_CENTER_2 || current_state==GET_GRAVITY_CENTER_3 || current_state==GET_GRAVITY_CENTER_5 )
		begin x_cnt <= x_cnt; y_cnt <= y_cnt; end
	else
		begin x_cnt <= 10'd0; y_cnt <= 10'd0; end
end
endmodule
*/