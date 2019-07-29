module camera_top (
	input 	 wire     				reset,											 //The low active
	input	 	 wire	    				clk,                                    //100Mhz
	input  	 wire        			SDRAMFlag,                              //The state start the high active
	input  	 wire         			rd_burst_finish,                        //read data is end 	
	input  	 wire    [15:0]		rd_burst_data,									 // input read data
	output 	 wire        			rd_burst_req,									 // output read request
	output 	 reg     [23:0] 		rd_burst_addr,									 // address
	input     wire       			rd_burst_data_valid,
	output    wire 	[16:0]		Angle,                                  //out angle  --  0.01
	output    wire		[15:0]		code												 // 16bit code

);


//***************The state final flag*******************///////////
wire				     FirstRC_flag;                            // First Roughly circle result Flag
wire                FirstPC_flag;                            // First Precision circle result Flag
wire                SecondC_flag;                            // Second  circle result Flag


reg                 FSFlag;                              	 // Final Success Flag
reg                 SFFlag;                              	 // Second Frame Flag

//***************The state start flag*******************// 
reg 					FirstCC_start;
reg 					FirstPC_start;
reg 					SecondC_start;
reg 					Final_start;
reg				   ResultErrorFlag; 
reg 					FirstPC_start_d,FirstPC_start_dd;
reg					SecondC_start_d,SecondC_start_dd; // All result Error Flag
//**********The final result***************************///
wire  [9:0]   		circle_x;
wire  [9:0]   		circle_y;

//***********************Results***********************//

wire  [9:0]			FirstR_resultx;
wire	[9:0]			FirstR_resulty;


wire	[9:0]			FirstP_resultx;
wire	[9:0]			FirstP_resulty;

wire	[9:0]		   Second_resultx;
wire	[9:0]			Second_resulty;



//************Request***SDRAM Addr***********************//
wire [9:0] 			First1_Reqaddrx;
wire [9:0] 			First1_Reqaddry;

wire [9:0] 			First2_Reqaddrx;
wire [9:0] 			First2_Reqaddry;

wire [9:0] 			Second_Reqaddrx;
wire [9:0] 			Second_Reqaddry;

wire [9:0]			Final_Reqaddrx;
wire [9:0]			Final_Reqaddry;
	
//***************data request*********************//
wire pt_req,req_valid;
reg second_pt_req,second_pt_req_d,second_pt_req_dd;

reg [4:0] current_state,next_state;
reg RC_cnt;
reg pt_req_f;

wire [9:0] location_x;
wire [9:0] location_y;
wire [23:0] location_y_R;


reg 		 pixl_bit;

parameter	IDLE			 = 5'b00001;              // IDLE
parameter	FRouCC 	    = 5'b00010;              // first find circle--roughly
parameter	FPreCC 		 = 5'b00100;              // first find circle--precision
parameter	SFindCC 	    = 5'b01000;              // second find circle
parameter   FResult      = 5'b10000;              // Final result -- double circle and angle

// one or zero 
always @(posedge clk or negedge reset)
begin
	if(!reset)
		pixl_bit <= 1'b0;
	else
		begin
			if(rd_burst_data_valid)
				begin
				if(rd_burst_data >= 16'd400)
					pixl_bit <= 1'b0;
				else
					pixl_bit <= 1'b1;
				end
			else
				pixl_bit <= pixl_bit;
		end
end

always @ (posedge clk) begin  end


always@(posedge clk or negedge reset)
begin
	if (!reset)
		current_state <= IDLE;
	else
		current_state <= next_state;
end
//Step by step to find the center of the process state machine
//State machine that accesses SDRAM every time
//Results per step machine
always @(*)
begin
	case (current_state)
		IDLE		    : if(SDRAMFlag) 		next_state <= FRouCC ;else next_state <= IDLE;
		FRouCC	    : if(FirstRC_flag) 	next_state <= FPreCC	;else if (ResultErrorFlag) next_state <= IDLE;else next_state <= FRouCC;
		FPreCC		 : if(FirstPC_flag) 	next_state <= SFindCC;else if (ResultErrorFlag) next_state <= IDLE;else next_state <= FPreCC;
		SFindCC	    : if(SecondC_flag) 	next_state <= FResult;else if (ResultErrorFlag) next_state <= IDLE;else next_state <= SFindCC;
		FResult		 : if(FSFlag)			next_state <= IDLE	;else next_state <= FResult;
		default	    : next_state <= IDLE;
	endcase
end


always @(posedge clk or negedge reset)
begin
if(!reset)
	begin
		FirstCC_start <= 1'b0; FirstPC_start <= 1'b0; SecondC_start <= 1'b0; Final_start <= 1'b0;
	end
else
	case(current_state)
		IDLE		    : begin FirstCC_start <= 1'b0; FirstPC_start <= 1'b0; SecondC_start <= 1'b0; Final_start <= 1'b0;end
		FRouCC	    : begin FirstCC_start <= 1'b1; FirstPC_start <= 1'b0; SecondC_start <= 1'b0; Final_start <= 1'b0;end
		FPreCC		 : begin FirstCC_start <= 1'b0; FirstPC_start <= 1'b1; SecondC_start <= 1'b0; Final_start <= 1'b0;end
		SFindCC	    : begin FirstCC_start <= 1'b0; FirstPC_start <= 1'b0; SecondC_start <= 1'b1; Final_start <= 1'b0;end
		FResult		 : begin FirstCC_start <= 1'b0; FirstPC_start <= 1'b0; SecondC_start <= 1'b0; Final_start <= 1'b1;end
		default		 :	begin FirstCC_start <= 1'b0; FirstPC_start <= 1'b0; SecondC_start <= 1'b0; Final_start <= 1'b0;end
	endcase
end


always @(posedge clk) begin  FirstPC_start_d <= FirstPC_start; FirstPC_start_dd <= FirstPC_start_d ; end
always @(posedge clk) begin  SecondC_start_d <= SecondC_start; SecondC_start_dd <= SecondC_start_d ; end
//always @(posedge clk) begin  Final_start_d <= Final_start; SecondC_start_dd <= SecondC_start_d ; end


always @(posedge clk) second_pt_req_d <= second_pt_req;

assign location_x = (current_state == FRouCC) ? First1_Reqaddrx : 
						  (current_state == FPreCC) ? First2_Reqaddrx :
						  (current_state == SFindCC)? Second_Reqaddrx :
						  (current_state == FResult)? Final_Reqaddrx:
						  10'd0;
assign location_y = (current_state == FRouCC) ? First1_Reqaddry : 
						  (current_state == FPreCC) ? First2_Reqaddry :
						  (current_state == SFindCC)? Second_Reqaddry :
						  (current_state == FResult)? Final_Reqaddry:
						  10'd0;
		  						  
assign rd_burst_req = (current_state == FRouCC) ? pt_req : 
							 (current_state == FPreCC) ? req_valid :
							 (current_state == SFindCC)?(second_pt_req_d&second_pt_req):
							 (current_state == FResult)?(pt_req_f):
							 1'd0;
							  
								  
always @(posedge clk) rd_burst_addr <= location_x + location_y_R + 3'd4;								 
								 
	
assign circle_x   = FirstRC_flag? FirstR_resultx:
                    FirstPC_flag? FirstP_resultx:
						  SecondC_flag? Second_resultx:
						  10'd0;

assign circle_y   = FirstRC_flag? FirstR_resulty:
                    FirstPC_flag? FirstP_resulty:
						  SecondC_flag? Second_resulty:
						  10'd0;

MULT	MULT_inst (
	.clock ( clk ),
	.dataa ( location_y ),
	.result ( location_y_R )
	);
						  


//The first find circle -- roughly 
 FindCircleRough FindCircleRough_inst(
	. clk(clk),
	. rst_n(reset),
	. start(FirstCC_start), 							// high pluse
	. Ans_valid(rd_burst_finish), 						//high pluse
	. pt_req(pt_req),								//read start
	. coordinate_x(First1_Reqaddrx),					//addr x
	. coordinate_y(First1_Reqaddry),					//addr y
	. pt_pixl_value(pixl_bit),					//data
	//when finish
	. circle_x(FirstR_resultx),						//output reasult x
	. circle_y(FirstR_resulty),						//output reasult y
	. finish(FirstRC_flag), 							// when finish is set Start must be reset
	. error(ResultErrorFlag)   						// Start must be reset
);

// The first find -- precision

circle circle_inst(
	. clk(clk),// 100Mhz
	. rst(reset),
	. enable((~FirstPC_start_dd)&&(FirstPC_start_d)),
	. app_adr_x(FirstR_resultx),
	. app_adr_y(FirstR_resulty),//approximate position
	. rec_data(pixl_bit),//request data
	. rec_data_vaild(rd_burst_finish), //request data finish
	. req_adr_x(First2_Reqaddrx),
	. req_adr_y(First2_Reqaddry),//request address
	. req_valid(req_valid),//request sign
	. coc_valid(FirstPC_flag),//centre of circle vaild
	. coc_adr_x(FirstP_resultx),
	. coc_adr_y(FirstP_resulty)//centre of circle
);

//The second find circle 

get_flag get_flag_inst(
	. clk(clk),//100MHz
	. rst_n(reset),//reset active negedge
	. start((~SecondC_start_dd)&&(SecondC_start_d)),// active high pulse
	. ctr_coords_x(FirstP_resultx), //center coords 
	. ctr_coords_y(FirstP_resulty),
	//request a value of a point
	. pt_valid(rd_burst_finish), // point value valid, active high pulse
	. pt_value(pixl_bit), // point value
	. pt_coords_x(Second_Reqaddrx), // point coords
	. pt_coords_y(Second_Reqaddry),
	. pt_req(second_pt_req), // point value request, active high pulse
	//report the flag point
	. flag_coords_x(Second_resultx), // flag coords
	. flag_coords_y(Second_resulty), // flag coords
	. complete(SecondC_flag) //active high pulse	
);


CircleDecode decodeHEX_inst(
		. clk(clk),
		. rst_n(reset),
		. st_sign(Final_start),
		. gap_x(Second_resultx),
		. gap_y(Second_resulty),
		. origin_x(FirstP_resultx),
		. origin_y(FirstP_resulty),
		. Ans_valid(rd_burst_finish),
		. pt_pixl_value(pixl_bit),
		. pt_req(pt_req_f),
		. location_x(Final_Reqaddrx),
		. location_y(Final_Reqaddry),
		. complete(FSFlag),
		. codOUT(code),
		. Angle(Angle)

);




endmodule



