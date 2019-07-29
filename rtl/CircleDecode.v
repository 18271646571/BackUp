module CircleDecode(
	input clk,
	input rst_n,
	input [9:0] origin_x,
	input [9:0] origin_y,
	input [9:0] gap_x,
	input [9:0] gap_y,
	

	input st_sign,    //起始信号
	input Ans_valid,   //应答信号
	input pt_pixl_value, 
	output wire pt_req,  // 请求信号
	output reg [9:0] location_x,  // 坐标x
	output reg [9:0] location_y,
	output reg [15:0] codOUT,        //获得的编码
	output reg complete,           //完成信号
	output reg [16:0] Angle    //  0 - 360 0.01
);

/****************clockwise*********************/
// x1 = x*cosa + y*sina
// y1 = y*cosa - x*sina
/****************Anti-clockwise*********************/
// x1 = x*cosa - y*sina
// y1 = y*cosa + x*sina

parameter   ideal = 3'd1,
			sin_cos = 3'd2,
			scan	= 3'd3,
			coding  = 3'd4,
			codEnd	= 3'd5;
parameter VALUE = 3'd3;

reg [2:0] current_state, next_state;
reg [5:0] cnt_time;//40 times wating for computer sin and cos 
reg [3:0] cnt_block;// recode 16 blocks 

reg [2:0] cnt_dot;  // every block have 5 dots
//reg st_scan;
reg [2:0] cnt_black;
reg [3:0] cnt_delay;
reg st_start;
reg [15:0] code;

wire signed [23:0] theta; //角度
reg [1:0] quad;  // quadrant 象限 

reg [9:0] value_x, value_y;


//reg [9:0] sintheta, costheta;
reg [6:0] rom_coodr_x,rom_coodr_y;
wire signed [6:0] rom_x,rom_y; //10
reg signed [21:0] coord_x,coord_y;
reg start_AG,start_SC;
reg signed [14:0] result_sin,result_cos;
wire [23:0] sin_temp, cos_temp;

reg [2:0] end_delay;

 
always @(posedge clk or negedge rst_n)
if(!rst_n)
	end_delay <= 3'd0;
else if(current_state == codEnd)
	end_delay <= end_delay + 1'b1;
else
	end_delay <= 3'd0;


 
always @(posedge clk or negedge rst_n)
if(!rst_n)
	current_state <= ideal;
else
	current_state <= next_state;

always @(*)
case(current_state)
	ideal  :if(st_sign) next_state = sin_cos; else next_state = ideal;
	sin_cos:if(cnt_time == 6'd40) next_state = scan; else next_state = sin_cos;
	scan   :if((cnt_block==4'd15)&& (cnt_dot == 3'd5)) next_state = coding; else next_state = scan;
	coding : next_state = codEnd;
	codEnd :if(end_delay == 3'd4) next_state = ideal; else next_state = codEnd;
	default : next_state = ideal;
endcase

always @(posedge clk or negedge rst_n)
if(!rst_n)
	cnt_time <= 6'd0;
else if(current_state == sin_cos)
	cnt_time <= cnt_time + 1'b1;
else
	cnt_time <= 6'd0;
	
	
always @(posedge clk or negedge rst_n)
if(!rst_n)
	complete <= 1'b0;
else if(current_state == coding)
	complete <= 1'b1;
else
	complete <= 1'b0;
	
always @(posedge clk or negedge rst_n)
if(!rst_n)
	codOUT <= 16'd0;
else if(current_state == coding)
	codOUT <= code;
else
	codOUT <= codOUT;
	


// request 
reg [2:0] st_con;
//simple state machine for read sdram
always @ (posedge clk) 
begin
	if(current_state == scan)
		st_start<=1'b1;
	else
		st_start <= 1'b0;
end 

// delay
always @(posedge clk or negedge rst_n)
if(!rst_n)
	cnt_delay <= 4'd0;
else if(st_con == 3'd1 )
	cnt_delay <= cnt_delay + 1'b1;
else
	cnt_delay <= 4'd0;


always @ (posedge clk or negedge rst_n )
begin
	if(!rst_n)
		st_con <= 3'd0;
	else 
		case (st_con) 
			3'd0 : if(st_start) st_con<=3'd1; else st_con<=3'd0;  //scan_coord stable
			3'd1 : if(cnt_delay == 4'd3) st_con<=3'd2; else st_con<=3'd1; //waiting computer 此处可以改变延时时间  满足时序要求
			3'd2 : st_con<=3'd3; //delay for coord stable
			3'd3 : st_con<=3'd4; //coordinate stable
			3'd4 : st_con<=3'd5; //coordinate_y_r stable
			3'd5 : st_con<=3'd6; //rd address stable and put request
			3'd6 : if(Ans_valid) st_con<=3'd0; else st_con<=3'd6;			
		default : st_con<=3'd0;
		endcase
end
assign pt_req = st_con[2] & st_con[1];
		

/******************/
// request and sent the coordinate of x and y
always @(posedge clk) if(st_con==3'd2) location_x <= origin_x  + coord_x[17:8];//{5'b0,coord_x[9:5]};
always @(posedge clk) if(st_con==3'd2) location_y <= origin_y  + coord_y[17:8];//{5'b0,coord_y[9:5]};

 // scan
// counter 80
always @(posedge clk or negedge rst_n)
if(!rst_n)
	cnt_dot <= 3'd0;
else if(current_state == scan)
	begin
		if(cnt_dot == 3'd5)
			cnt_dot <= 3'd0;
		else if(Ans_valid)
			cnt_dot <= cnt_dot + 1'b1;
		else 
			cnt_dot <= cnt_dot;
	end
else
		cnt_dot <= 3'd0;
		
		
always @(posedge clk or negedge rst_n)
if(!rst_n)
	cnt_block <= 4'd0;
else if(current_state == scan)
	begin
		if(cnt_dot == 3'd5)
			cnt_block <= cnt_block +1'b1;
		else
			cnt_block <= cnt_block;
	end
else
	cnt_block <= 4'd0;

	
always @(posedge clk or negedge rst_n)
if(!rst_n)
	begin
	rom_coodr_x <= 7'd0;
	rom_coodr_y <= 7'd0;
	end
else if(current_state == scan)
	begin
		rom_coodr_x <= cnt_block * 5 + cnt_dot;
		rom_coodr_y <= cnt_block * 5 + cnt_dot;
	end
else
	begin
		rom_coodr_x <= 7'd0;
		rom_coodr_y <= 7'd0;
	end


always @(posedge clk or negedge rst_n)
if(!rst_n)
	code <= 16'd0;
else if(current_state == ideal)
	code <= 16'd0;
else if(current_state == scan)
begin
	if(cnt_dot == 3'd5)
		begin
			if(cnt_black >= VALUE)
				code <= {code[14:0],1'b1};
			else
				code <= {code[14:0],1'b0};
		end
	else
		code <= code;
end
else
	code <= code;


// 记录黑点
always @(posedge clk or negedge rst_n)
if(!rst_n)
	cnt_black <= 3'd0;
else if(current_state == scan)
	begin 
		if(Ans_valid)
			cnt_black <= cnt_black + pt_pixl_value;
		else if(cnt_dot == 3'd5)
			cnt_black <= 3'd0;
		else
			cnt_black <= cnt_black;
	end
else
	cnt_black <= 3'd0;

/****************clockwise*********************/
// x1 = x*cosa + y*sina
// y1 = y*cosa - x*sina
/****************Anti-clockwise*********************/
// x1 = x*cosa - y*sina
// y1 = y*cosa + x*sina
/**************/
//    1    2    3   4
//sin +	   +    -   -
//cos +    -    -   +
always @(posedge clk or negedge rst_n)
if(!rst_n)
	begin
		coord_x <= 22'd0;
		coord_y <= 22'd0;
	end
else if(current_state == scan)
	case(quad)     //角度在四个不同的象限  计算公式不一样
		2'b00:begin coord_x <= rom_x* result_cos - rom_y*result_sin; 
					coord_y <= rom_y* result_cos + rom_x*result_sin;end  //  + -
					
		2'b01:begin coord_x <= rom_x* result_cos + rom_y*result_sin; 
					coord_y <= rom_y* result_cos - rom_x*result_sin; end   // - +
					
		2'b10:begin coord_x <= rom_x* result_cos + rom_y*result_sin; 
					coord_y <= rom_y* result_cos - rom_x*result_sin;  end  //- +
					
		2'b11:begin coord_x <= rom_x* result_cos - rom_y*result_sin;    //+ -
					coord_y <= rom_y* result_cos + rom_x*result_sin;end
	endcase
else
	begin
		coord_x <= coord_x;
		coord_y <= coord_y;
	end





value_x value_xINST(
	.address(rom_coodr_x),
	.clock(clk),
	.q(rom_x) //11 bits
);	
	
value_y value_yINST(
	.address(rom_coodr_y),
	.clock(clk),
	.q(rom_y)
);		
/**************************/
//判断象限 确定旋转方向
always @(posedge clk or negedge rst_n)
if(!rst_n)
	quad <= 2'b00;
else if((gap_x >=  origin_x)&&(  gap_y <= origin_y)) begin quad <= 2'b00; end
else if((gap_x <  origin_x)&&(  gap_y <= origin_y)) begin quad <= 2'b01; end
else if((gap_x <=  origin_x)&&(  gap_y >= origin_y)) begin quad <= 2'b10; end
else if((gap_x >  origin_x)&&(  gap_y >= origin_y)) begin quad <= 2'b11; end
else begin quad <= quad; end

always @(posedge clk or negedge rst_n)
if(!rst_n)
	begin 
		value_x <= 10'd0;
		value_y <= 10'd0;
	end
else if(cnt_time== 6'd1) // 
	case(quad)
		2'b00:begin value_x <= gap_x + (~origin_x + 1'b1); value_y <= origin_y + (~gap_y + 1'b1);end
		2'b01:begin value_x <= origin_x + (~gap_x + 1'b1); value_y <= origin_y + (~gap_y + 1'b1);end
		2'b10:begin value_x <= origin_x + (~gap_x + 1'b1); value_y <= gap_y + (~origin_y + 1'b1);end
		2'b11:begin value_x <= gap_x + (~origin_x + 1'b1); value_y <= gap_y + (~origin_y + 1'b1);end
	endcase
else
begin 
	value_x <= value_x;
	value_y <= value_y;
end


always @(posedge clk or negedge rst_n)
if(!rst_n)
	begin 
		start_AG <= 1'd0;
		start_SC <= 1'd0;
	end
else if(cnt_time == 6'd2) start_AG <= 1'b1;
else if(cnt_time == 6'd19) start_SC <= 1'b1;
else begin 	start_AG <= 1'd0;	start_SC <= 1'd0;end

always @(posedge clk or negedge rst_n)
if(!rst_n)
	begin 
		result_cos <= 15'd0;
		result_sin <= 15'd0;
	end
else if(cnt_time == 6'd38)
	case(quad)
		2'b00:begin	result_cos <= cos_temp[14:0];		 result_sin <= sin_temp[14:0]; end
		2'b01:begin	result_cos <= cos_temp[14:0];		 result_sin <= sin_temp[14:0]; end
		2'b10:begin	result_cos <= ~cos_temp[14:0] + 1'b1;result_sin <= sin_temp[14:0]; end
		2'b11:begin	result_cos <= ~cos_temp[14:0] + 1'b1;result_sin <= sin_temp[14:0]; end
	endcase
else
	begin 
		result_cos <= result_cos;
		result_sin <= result_sin;
	end	



always @(posedge clk or negedge rst_n)
if(!rst_n)
		Angle  <= 17'd0;
else if(cnt_time == 6'd19)
	case(quad)
		2'b00: Angle <= theta[16:0] + 17'd69120;
		2'b01: Angle <= theta[16:0];
		2'b10: Angle <= theta[16:0] + 17'd23040;
		2'b11: Angle <= theta[16:0] + 17'd46080;
	endcase
else
	Angle <= Angle;


atan  ataninst(
	.clk(clk),
	.rst(rst_n),
	.din_a({14'b0,value_y}),
	.din_b({14'b0,value_x}),
	.angle_o(theta),
	.start(start_AG)
	);
	
sincos sincosinst(
	.clk(clk),
	.rst(rst_n),
	.angle_o(theta),
	.start(start_SC),
	.cos_t(cos_temp),
	.sin_t(sin_temp) //hou 8 bit 
);
	

endmodule
