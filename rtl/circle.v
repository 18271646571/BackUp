module circle(
input				clk,// 100Mhz
input				rst,
input				enable,
input[9:0]			app_adr_x,
input[9:0]			app_adr_y,//approximate position
input				rec_data,//request data
input				rec_data_vaild, //request data vaild
output	reg[9:0]	req_adr_x,
output	reg[9:0]	req_adr_y,//request address
output	wire			req_valid,//request sign
output	reg			coc_valid,//centre of circle vaild
output	reg[9:0]	coc_adr_x,
output	reg[9:0]	coc_adr_y,//centre of circle
output  reg			error
);

reg[7:0]		state,next_state;
reg[4:0]		count_x,count_y;
reg[15:0]		sum_x,sum_y;
reg[15:0]			point;
wire[15:0]	quotient_x,quotient_y,remainder_x,remainder_y;
reg[9:0]		temp_x,temp_y;


parameter	IDLE = 8'b00000001;
parameter	REC = 8'b00000010;
parameter	CUP = 8'b00000100;
parameter	ADD = 8'b00001000;
parameter	OUT = 8'b00010000;
parameter	WAIT = 8'b00100000;
parameter	WAITTWO = 8'b01000000;
parameter	DENG = 8'b10000000;

always@(posedge clk or negedge rst)
begin
	if(!rst)
		state <= IDLE;
	else
		state <= next_state;
end

always@(posedge clk or negedge rst)
begin
	if(!rst)
		count_x <= 5'd0;
	else if(count_x == 5'd20 || state == IDLE)
		count_x <= 5'd0;
	else if(state == CUP)
		count_x <= count_x + 1'b1;
	else
		count_x <= count_x;
end

always@(posedge clk or negedge rst)
begin
	if(!rst)
		count_y <= 5'd0;
	else if(count_y == 5'd21 || state == IDLE)
		count_y <= 5'd0;
	else if(count_x == 5'd20)
		count_y <= count_y + 1'b1;
	else
		count_y <= count_y;
end



always@(*)
begin
	case(state)
		IDLE:if(enable) next_state = WAIT; else next_state = IDLE;
		WAIT:next_state = WAITTWO;
		WAITTWO:next_state = DENG;
		DENG:next_state = REC;
		REC:if(rec_data_vaild) next_state = CUP; else next_state = REC;
		CUP:next_state = ADD;
		ADD:if(count_y == 5'd20) next_state = OUT; else next_state = WAIT;
		OUT:next_state = IDLE;
		default: next_state = IDLE;
	endcase
end

assign req_valid = state[1];

always@(posedge clk)
begin
	case(state)
		IDLE:
			begin
				sum_x <= 0;sum_y <= 0;point <= 0;coc_valid <= 1'b0;
				temp_x <= app_adr_x +10'd1019; temp_y <= app_adr_y + 10'd1019;req_adr_x <= app_adr_x + 10'd1019;req_adr_y <= app_adr_y + 10'd1019;
			end

		CUP:
			begin
				if(rec_data == 1)
					begin
						sum_x <= sum_x + req_adr_x;
						sum_y <= sum_y + req_adr_y;
						point <= point + 1;
					end
				else
					begin
						sum_x <= sum_x;
						sum_y <= sum_y;
						point <= point;
					end
			end
		ADD:
			begin
				req_adr_x <= temp_x + count_x;
				req_adr_y <= temp_y + count_y;
			end
		OUT:
			begin
				if(remainder_x[9:0] > {1'b0,point[9:1]})
					coc_adr_x <= quotient_x[9:0] + 1'b1;
				else
					coc_adr_x <= quotient_x[9:0];
				if(remainder_y[9:0] > {1'b0,point[9:1]})
					coc_adr_y <= quotient_y[9:0] + 1'b1;
				else
					coc_adr_y <= quotient_y[9:0];
				coc_valid <= 1'b1;
			end
	endcase
end


divider_wh divider_wh_inst_x
( 
	.a(sum_x),
	.b(point),
	.quotient(quotient_x),
	.remainder(remainder_x)
); 
divider_wh divider_wh_inst_y
( 
	.a(sum_y),
	.b(point),
	.quotient(quotient_y),
	.remainder(remainder_y)
); 



endmodule 



/*

reg[6:0]		state,next_state;
reg[5:0]		count_x,count_y;
reg[15:0]		sum_x,sum_y;
reg[15:0]			point;
wire[15:0]	quotient_x,quotient_y,remainder_x,remainder_y;
reg[9:0]		temp_x,temp_y;


parameter	IDLE = 7'b0000001;
parameter	WAIT = 7'b0000010;
parameter	DENG = 7'b0000100;
parameter	REC = 7'b0001000;
parameter	CUP = 7'b0010000;
parameter	ADD = 7'b0100000;
parameter	OUT = 7'b1000000;



always@(posedge clk or negedge rst)
begin
	if(!rst)
		state <= IDLE;
	else
		state <= next_state;
end

always@(posedge clk or negedge rst)
begin
	if(!rst)
		count_y <= 5'd0;
	else if(count_y == 5'd25 || state == IDLE)
		count_y <= 5'd0;
	else if(state == CUP)
		count_y <= count_y + 1'b1;
	else
		count_y <= count_y;
end

always@(posedge clk or negedge rst)
begin
	if(!rst)
		count_x <= 5'd0;
	else if(count_x == 5'd26 || state == IDLE)
		count_x <= 5'd0;
	else if(count_y == 5'd25)
		count_x <= count_x + 1'b1;
	else
		count_x <= count_x;
end

assign req_valid  = state[3];

always@(*)
begin
	case(state)
		IDLE:if(enable) next_state = WAIT; else next_state = IDLE;
		WAIT:next_state = DENG;
		DENG:next_state = REC;
		REC:if(rec_data_vaild) next_state = CUP; else next_state = REC;
		CUP:next_state = ADD;
		ADD:if(count_x == 5'd25) next_state = OUT; else next_state = WAIT;
		OUT:next_state = IDLE;
		default: next_state = IDLE;
	endcase
end


always@(posedge clk)
begin
	case(state)
		IDLE:
			begin
				sum_x <= 0;sum_y <= 0;point <= 0;coc_valid <= 1'b0;
				temp_x <= app_adr_x +10'd1019; temp_y <= app_adr_y + 10'd1019;req_adr_x <= app_adr_x + 10'd1019; req_adr_y <= app_adr_y + 10'd1019;
			end
		CUP:
			begin
				if(rec_data == 1'b1)
					begin
						sum_x <= sum_x + req_adr_x;
						sum_y <= sum_y + req_adr_y;
						point <= point + 1'b1;
					end
				else
					begin
						sum_x <= sum_x;
						sum_y <= sum_y;
						point <= point;
					end
			end
		ADD:
			begin
				req_adr_x <= temp_x + count_x;
				req_adr_y <= temp_y + count_y;
			end
		OUT:
			begin
				if(remainder_x[9:0] > 10'b0000000101)
					coc_adr_x <= quotient_x[9:0] + 1'b1;
				else
					coc_adr_x <= quotient_x[9:0];
				if(remainder_y[9:0] > 10'b0000000101)
					coc_adr_y <= quotient_y[9:0] + 1'b1;
				else
					coc_adr_y <= quotient_y[9:0];
				coc_valid <= 1'b1;
			end
	endcase
end


divider divider_inst_x
( 
	.a(sum_x),
	.b(point),
	.quotient(quotient_x),
	.remainder(remainder_x)
); 
divider divider_inst_y
( 
	.a(sum_y),
	.b(point),
	.quotient(quotient_y),
	.remainder(remainder_y)
); 



endmodule 
*/