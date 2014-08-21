module seven_segment(
		input      [3:0] value,
		output reg [6:0] display
	);
	
	always @( value ) begin
		case( value )
			0: display <= 7'b1000000;
			1: display <= 7'b1001111;
			2: display <= 7'b0100100;
			3: display <= 7'b0110000;
			4: display <= 7'b0011001;
			5: display <= 7'b0010010;
			6: display <= 7'b0000010;
			7: display <= 7'b1111000;
			8: display <= 7'b0000000;
			9: display <= 7'b0011000;
			default: display <= 7'b1111111;
		endcase
	end
endmodule