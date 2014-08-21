module clock(
		// Physical IO devices
		input  [0:0] CLOCK_24,
		input  [1:0] KEY,
		output [6:0] HEX0,
		output [6:0] HEX1,
		output [6:0] HEX2,
		output [6:0] HEX3,
		output [13:0] GPIO_0
	);
	
	// Time keeping
	reg  [24:0] int_count;
	reg  [5:0] seconds;
	reg  [5:0] minutes;
	reg  [4:0] hours;
	reg  [5:0] days;
	reg  [4:0] months;
	reg  [6:0] years;
	
	// BCD decoding
	reg  [7:0] bcd_input;
	wire [3:0] bcd_output_ones;
	wire [3:0] bcd_output_tens;
	wire [3:0] bcd_output_hundreds;
	
	bcd bcd_decoder(
		.value( bcd_input ),
		.hundreds( bcd_output_hundreds ),
		.tens( bcd_output_tens ),
		.ones( bcd_output_ones )
	);
	
	// 7 segment decoding
	reg  [3:0] ss_input;
	wire [6:0] ss_output;
	
	seven_segment ss_decoder(
		.value( ss_input ),
		.display( ss_output )
	);
	
	// Display output buffer
	reg  [3:0] display_counter;
	reg  [6:0] display_buffer [0:5];
	assign GPIO_0[13:7] = display_buffer[0];
	assign GPIO_0[6:0]  = display_buffer[1];
	assign HEX0         = display_buffer[2];
	assign HEX1         = display_buffer[3];
	assign HEX2         = display_buffer[4];
	assign HEX3         = display_buffer[5];
	
	// State machine
	reg  [3:0] set_state;
	
	// User input
	reg key_ff1 [0:1];
	reg key_ff2 [0:1];
	reg key_reg [0:1];
	
	// Setup the initial values
	initial begin
		// Timing initial values
		int_count = 0;
		seconds = 0;
		minutes = 0;
		hours = 0;
		
		days = 1;
		months = 1;
		years = 0;
		
		// Initial state
		set_state = 0;
		
		// Display initial values
		display_counter = 0;
	end
	
	integer i;
	
	// Metastability fix for the user input
	always @( posedge CLOCK_24[0] ) begin
		for( i=1; i>=0; i=i-1 ) begin
			key_ff1[i] <= !KEY[i];
			key_ff2[i] <= key_ff1[i];
		end
	end
	
	always @( posedge CLOCK_24[0] ) begin
		// Time keeping
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
				days = days + 1;
			end
			
			// If we're in a set mode allow the day to go to 31 for any month, this lets the user set the date to 29 feb etc.
			if( ( months == 4 || months == 6 || months == 9 || months == 11 ) && days == 31 && set_state == 0 ) begin
				months = months + 1;
				days = 1;
			end
			else if( months == 2 && years[1:0] == 0 && days == 30 && set_state == 0 ) begin
				months = months + 1;
				days = 1;
			end
			else if( months == 2 && years[1:0] != 0 && days == 29 && set_state == 0 ) begin
				months = months + 1;
				days = 1;
			end
			else if( days == 32 ) begin
				months = months + 1;
				days = 1;				
			end
			
			if( months == 13 ) begin
				months = 1;
				years = years + 1;
			end
		end
		
		// User input
		
		// Set button - changes state
		if( key_ff2[0] && !key_reg[0] ) begin
			set_state = set_state + 1;
			
			// States wrap around at max + 1
			if( set_state == 7 )
				set_state = 0;
			
			key_reg[0] = 1;
		end
		
		// "Mode" button - changes values
		if( key_ff2[1] && !key_reg[1] ) begin
			case( set_state )
				1: begin
					hours = hours + 1;
					if( hours == 24 )
						hours = 0;
				end
				2: begin
					minutes = minutes + 1;
					if( minutes == 60 )
						minutes = 0;
				end
				3: begin
					seconds = 0;
					int_count = 0;
				end
				4: begin
					days = days + 1;
					if( days == 32 )
						days = 1;
				end
				5: begin
					months = months + 1;
					if( months == 13 )
						months = 1;
				end
				6: begin
					years = years + 1;
					if( years == 100 )
						years = 0;
				end
			endcase
			
			key_reg[1] = 1;
		end
		
		for( i=1; i>=0; i=i-1 ) begin
			if( !key_ff2[i] )
				key_reg[i] = 0;
		end
		
		// BCD management
		if( key_ff2[1] && set_state == 0 || set_state > 3 ) begin
			// Display date when holding mode or setting date element
			case( display_counter[3:1] )
				0: bcd_input = months;
				1: bcd_input = days;
				2: bcd_input = years;
			endcase
		end
		else begin
			// Display time
			case( display_counter[3:1] )
				0: bcd_input = minutes;
				1: bcd_input = hours;
				2: bcd_input = seconds;
			endcase
		end
		
		// 7 Segment management
		if( display_counter[0] )
			ss_input = bcd_output_ones;
		else
			ss_input = bcd_output_tens;
		
		display_buffer[display_counter] = ss_output;
		
		// Flashing display for setting the correct values
		if( int_count[22] == 0 ) begin
			case( set_state )
				// Hours - minutes - seconds
				1,4: begin
					display_buffer[5] = 7'b1111111;
					display_buffer[4] = 7'b1111111;
				end
				2,5: begin
					display_buffer[3] = 7'b1111111;
					display_buffer[2] = 7'b1111111;
				end
				3,6: begin
					display_buffer[1] = 7'b1111111;
					display_buffer[0] = 7'b1111111;
				end
			endcase
		end
		
		display_counter = display_counter + 1;
		if( display_counter == 6 )
			display_counter = 0;
	end
endmodule