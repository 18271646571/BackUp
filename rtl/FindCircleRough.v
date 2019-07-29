module FindCircleRough(
input clk,
input rst_n,
input start, // high pluse
input Ans_valid, //high pluse
output wire pt_req,
output reg [9:0] coordinate_x,
output reg [9:0] coordinate_y,
input pt_pixl_value,
//when finish
output reg [9:0] circle_x,
output reg [9:0] circle_y,
output reg finish, // when finish is set Start must be reset
output reg error   // Start must be reset
);

wire [9:0] coord_x,coord_y;

reg [8:0] current_state,next_state;
reg [4:0] scan_coord;


reg [3:0] cnt_mid;
reg [3:0] cnt_Inn;
reg [3:0] cnt_Out;

reg [2:0] delay_cnt;

reg [9:0] cnt_levelX;
reg [9:0] cnt_erectY;
reg [2:0] st_con;
reg st_start;

parameter orgin_x = 10'd110 ,orgin_y = 10'd110;

parameter 	ideal  = 9'b0_0000_0001,
			Cycle   = 9'b0_0000_0010,
			Mid_cir = 9'b0_0000_0100,
			cal_pt_1= 9'b0_0000_1000,
			Inn_cir = 9'b0_0001_0000,
			cal_pt_2= 9'b0_0010_0000,
			Out_cir = 9'b0_0100_0000,
			cal_pt_3= 9'b0_1000_0000,
			End_cir = 9'b1_0000_0000,
			delay   = 9'b1_0000_0001;




//simple state machine for read sdram
always @ (posedge clk) 
begin
	if((current_state == Mid_cir)||(current_state == Inn_cir)||(current_state == Out_cir))
		st_start<=1'b1;
	else 
		st_start<=1'b0;
end 

always @ (posedge clk or negedge rst_n )
begin
	if(!rst_n)
		st_con <= 3'd0;
	else if(current_state == Cycle)
		st_con<=3'd0;
	else 
		case (st_con) 
			3'd0 : if(st_start) st_con<=3'd1; else st_con<=3'd0;  //scan_coord stable
			3'd1 : st_con<=3'd2; //delay for coord stable
			3'd2 : st_con<=3'd3; //coordinate stable
			3'd3 : st_con<=3'd4; //coordinate_y_r stable
			3'd4 : st_con<=3'd5; //rd address stable and put request
			3'd5 : if(Ans_valid) st_con<=3'd0; else st_con<=3'd5;			
		default : st_con<=3'd0;
		endcase
end

assign pt_req = st_con[2];



// sacn 10 point 	
always @(posedge clk or negedge rst_n )
if(!rst_n)
	scan_coord <= 5'd0;
else if(current_state == Cycle)
	scan_coord <= 5'd0;
else if(Ans_valid)
	scan_coord <= scan_coord + 1'b1;
else
	scan_coord <= scan_coord;
	
//traversal horizontal X   120
always @(posedge clk or negedge rst_n)
if(!rst_n)
	begin cnt_levelX <= 10'd0;cnt_erectY <= 10'd0; end
else if(current_state == ideal)
	begin cnt_levelX <= 10'd0;cnt_erectY <= 10'd0; end
else if((current_state == Cycle))
	begin 
		if(cnt_levelX == 10'd94) begin cnt_levelX <= 10'd0; cnt_erectY <= cnt_erectY + 1'b1; end
		else begin cnt_levelX <= cnt_levelX + 1'b1; cnt_erectY <= cnt_erectY; end		
	end
else
	begin cnt_levelX <= cnt_levelX;cnt_erectY <= cnt_erectY; end
	

// create error 
always @(posedge clk or negedge rst_n)
if(!rst_n)
	error <= 1'b0;
else if(cnt_erectY > 10'd55)
	error <= 1'b1;
else
	error <= 1'b0;
	
always @(posedge clk or negedge rst_n)
if(!rst_n)
	current_state <= ideal;
else
	current_state <= next_state;

always @(*)
case(current_state)
	ideal   :if(start) next_state <= Cycle; else next_state <= ideal;
	Cycle   :if(error)next_state<=ideal;else next_state <= Mid_cir;
	Mid_cir :if(scan_coord == 5'd10) next_state <= cal_pt_1; else next_state <= Mid_cir;
	cal_pt_1:if(cnt_mid >= 4'd7) next_state <= Inn_cir; else next_state <= Cycle;
	Inn_cir :if(scan_coord == 5'd20) next_state <= cal_pt_2; else next_state <= Inn_cir;
	cal_pt_2:if(cnt_Inn <= 4'd3) next_state <= Out_cir; else next_state <= Cycle;
	Out_cir :if(scan_coord == 5'd30) next_state <= cal_pt_3; else next_state <= Out_cir;
	cal_pt_3:if(cnt_Out <= 4'd3) next_state <= End_cir; else next_state <= Cycle;
	End_cir :next_state <= delay;
	delay	  :if(delay_cnt == 3'd1) next_state <= ideal; else next_state <= delay;
	default :next_state <= ideal;
endcase


always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
		delay_cnt <= 3'd0;
	else if (current_state == delay)
		delay_cnt <= delay_cnt + 1'b1;
	else
		delay_cnt <= 3'd0;
end



// request and sent the coordinate of x and y
always @(posedge clk) if(st_con==3'd1) coordinate_x <= orgin_x + {cnt_levelX[7:0],2'b00} + coord_x;
always @(posedge clk) if(st_con==3'd1) coordinate_y <= orgin_y + {cnt_erectY[7:0],2'b00} + coord_y;
	
// calcute the black point
always @(posedge clk or negedge rst_n)
if(!rst_n)
	cnt_mid <= 4'd0;
else if(( current_state == Mid_cir  ))
	begin
	if(Ans_valid)
		cnt_mid <= cnt_mid + pt_pixl_value;
	else
		cnt_mid <= cnt_mid ;
	end
else
	cnt_mid <= 4'd0;


always @(posedge clk or negedge rst_n)
if(!rst_n)
	cnt_Inn <= 4'd0;
else if(( current_state == Inn_cir  ) )
	begin
	if(Ans_valid)
		cnt_Inn <= cnt_Inn + pt_pixl_value;
	else
		cnt_Inn <= cnt_Inn ;
	end
else
	cnt_Inn <= 4'd0;


always @(posedge clk or negedge rst_n)
if(!rst_n)
	cnt_Out <= 4'd0;
else if(( current_state == Out_cir  ) )
	begin
	if(Ans_valid)
		cnt_Out <= cnt_Out + pt_pixl_value;
	else
		cnt_Out <= cnt_Out ;
	end
else
	cnt_Out <= 4'd0;
	
//create finish sign
always @(posedge clk or negedge rst_n)
if(!rst_n)
	finish <= 1'b0;
else if(current_state ==  End_cir)
	finish <= 1'b1;
else
	finish <= 1'b0;
// send the coordinate of x y	
always @(posedge clk or negedge rst_n)
if(!rst_n)
	circle_x <= 10'd0;
else if(current_state == End_cir)
	circle_x <= orgin_x + {cnt_levelX[7:0],2'b00};
	
always @(posedge clk or negedge rst_n)
if(!rst_n)
	circle_y <= 10'd0;
else if(current_state == End_cir)
	circle_y <= orgin_y + {cnt_erectY[7:0],2'b00};
	
recoder_circle get_coordinate_x(
	.address(scan_coord),
	.clock(clk),
	.q(coord_x)
);

recorde_circle_y get_coordinate_y(
	.address(scan_coord),
	.clock(clk),
	.q(coord_y)
);

endmodule
