module clock(
		// Physical IO devices
		input [0:0] CLOCK_24,
		input [1:0] KEY,
		output reg [6:0] HEX0,
		output reg [6:0] HEX1,
		output reg [6:0] HEX2,
		output reg [6:0] HEX3,
		output reg [13:0] GPIO_0,
		// Use as AM/PM indicator
		output reg [0:0] LEDR
	);
	
	// Time keeping
	reg [24:0] int_count;
	reg [5:0] seconds;
	reg [5:0] minutes;
	reg [4:0] hours;
	reg [4:0] hours_draw;
	reg [2:0] state;
	reg [3:0] param [0:0];
	
	// Input
	reg key_ff1 [0:1];
	reg key_ff2 [0:1];
	reg key_reg [0:1];
	
	// Display from clock
	reg [3:0] val_disp [0:5];
	
	wire [6:0] clock_display [0:5];
	
	wire [3:0] second_ones;
	wire [3:0] second_tens;
	
	wire [3:0] minute_ones;
	wire [3:0] minute_tens;
	
	wire [3:0] hour_ones;
	wire [3:0] hour_tens;
	
	bcd bcd_seconds(
		.value( seconds ),
		.tens( second_tens ),
		.ones( second_ones )
	);
	
	seven_segment ss_disp0(
		.value( val_disp[0] ),
		.display( clock_display[0] )
	);
	
	seven_segment ss_disp1(
		.value( val_disp[1] ),
		.display( clock_display[1] ) );
		
	bcd bcd_minutes(
		.value( minutes ),
		.tens( minute_tens ),
		.ones( minute_ones )
	);
	
	seven_segment ss_disp2(
		.value( val_disp[2] ),
		.display( clock_display[2] )
	);
	
	seven_segment ss_disp3(
		.value( val_disp[3] ),
		.display( clock_display[3] ) );
		
	bcd bcd_hours(
		.value( hours_draw ),
		.tens( hour_tens ),
		.ones( hour_ones )
	);
	
	seven_segment ss_disp4(
		.value( val_disp[4] ),
		.display( clock_display[4] )
	);
	
	seven_segment ss_disp5(
		.value( val_disp[5] ),
		.display( clock_display[5] ) );
	
	// Setup the initial values
	initial begin
		int_count = 0;
		seconds = 0;
		minutes = 0;
		hours = 0;
		state = 0;
		
		// Default settings
		param[0] = 0;
	end
	
	integer i;
	
	always @( posedge CLOCK_24[0] ) begin
		for( i=1; i>=0; i=i-1 ) begin
			key_ff1[i] <= !KEY[i];
			key_ff2[i] <= key_ff1[i];
		end
	end
	
	always @( posedge CLOCK_24[0] ) begin
		if( key_ff2[0] && !key_reg[0] ) begin
			// If we are in the clock state AND we are holding the other button
			if( state == 0 && key_ff2[1] ) begin
				// We will then enter the other settings - eg 12/24 hour
				state = 4;
			end
			else begin
				// Otherwise stay in normal states
				state = state + 1;
				// State == 4 is end of time set, == 5 is end of param set
				if( state == 4 || state == 5 ) begin
					state = 0;
				end
			end
			key_reg[0] = 1;
		end
		
		if( key_ff2[1] && !key_reg[1] ) begin
			case( state )
				1: begin
					hours = hours + 1;
					if( hours == 24 ) begin
						hours = 0;
					end
				end
				2: begin
					minutes = minutes + 1;
					if( minutes == 60 ) begin
						minutes = 0;
					end
				end
				3: begin
					seconds = 0;
					int_count = 0;
				end
				4: begin
					param[0] = param[0] + 1;
					if( param[0] == 2 ) begin
						param[0] = 0;
					end
				end
			endcase
			
			key_reg[1] = 1;
		end
		
		for( i=1; i>=0; i=i-1 ) begin
			if( !key_ff2[i] ) begin
				key_reg[i] = 0;
			end
		end
		
		int_count = int_count + 1;
		
		// Divide 24MHz by 24000000 to get 1Hz
		if( int_count == 24000000 ) begin
			seconds = seconds + 1;
			int_count = 0;
		
			if( seconds == 60 ) begin
				seconds = 0;
				minutes = minutes + 1;
			end
			
			if( minutes == 60 ) begin
				minutes = 0;
				hours = hours + 1;
			end
			
			if( hours == 24 ) begin
				hours = 0;
			end
		end
		
		// These are clock display like states - eg time, set hour/minute/second
		if( state < 4 ) begin
			hours_draw = hours;
			LEDR[0] = 0;
			
			if( param[0] && hours >= 12 ) begin
				hours_draw = hours - 12;
				LEDR[0] = 1;
			end
			
			if( param[0] && hours_draw == 0 ) begin
				hours_draw = 12;
			end
		
			// In clock mode all displays are just that of the BCD output
			val_disp[0] = second_ones;
			val_disp[1] = second_tens;
			val_disp[2] = minute_ones;
			val_disp[3] = minute_tens;
			val_disp[4] = hour_ones;
			val_disp[5] = hour_tens;
			
			// And all go straight to the displays
			GPIO_0[13:7] = clock_display[0];
			GPIO_0[6:0] = clock_display[1];
			
			HEX0 = clock_display[2];
			HEX1 = clock_display[3];
			HEX2 = clock_display[4];
			HEX3 = clock_display[5];
		end
		else if( state >= 4 ) begin
			// Parameter states - display paramater number and value
			val_disp[0] = param[state - 4];
			val_disp[5] = state - 4;
			
			GPIO_0[13:7] = clock_display[0];
			HEX3 = clock_display[5];
			
			GPIO_0[6:0] = 7'b1111111;
			HEX0 = 7'b1111111;
			HEX1 = 7'b1111111;
			HEX2 = 7'b1111111;
		end
		
		// Flashing display for setting the correct values
		if( int_count[22] == 0 ) begin
			case( state )
				1: begin
					HEX2 = 7'b1111111;
					HEX3 = 7'b1111111;
				end
				2: begin
					HEX0 = 7'b1111111;
					HEX1 = 7'b1111111;
				end
				3: begin
					GPIO_0[13:7] = 7'b1111111;
					GPIO_0[6:0] = 7'b1111111;
				end
			endcase
		end
	end
endmodule