module divider_wh
( 
input [15:0] a,//被除数 
input [15:0] b,//除数 
output reg [15:0] quotient,//商 
output reg [15:0] remainder//余数 
); 
reg [15:0] a_in; 
reg [15:0] b_in; 
reg [31:0] temp_a; 
reg [31:0] temp_b; 
integer i; 

always@(*)
begin
	a_in = a;
	b_in = b;
end

always@(*) 
begin 
	temp_a = {16'h0,a_in}; 
	temp_b = {b_in,16'h0}; 
	for(i = 0; i < 16; i = i+1) //注意是移动11次 
		begin
			temp_a = {temp_a[30:0],1'b0} ; 
			if(temp_a[31:16] >= temp_b[31:16] ) 
				temp_a = temp_a - temp_b + 1; 
			else temp_a = temp_a; 
		end 
	quotient = temp_a[15:0];//商在低位 
	remainder = temp_a[31:16];//余数在高位 
end 
endmodule
