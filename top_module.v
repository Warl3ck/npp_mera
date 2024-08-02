`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.01.2023 16:29:52
// Design Name: 
// Module Name: top_module
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module top_module #(
    parameter DATA_WIDTH = 16,
    parameter NUM_OF_TRANSACTION = 4,
    parameter CLK_PERIOD = 25,
    parameter USB_CHECK_PERIOD = 100000
)
(
    input      	clk,
    input      	rst,
    input       ack,
    //
    input       gpi_status,
    //
    output     	fx3_pclk,   // 40 MHz
    output     	fx3_rst,    // reset active high
    inout    	[DATA_WIDTH-1:0] fx3_dq,
    output		intr
);




wire    clk_i;
reg     [3:0] rst_cdc;
reg     fx3_rst_i;
reg     fx3_rst_z;
wire    reset_done_strb;

integer counter = 0, count_tdata = 0, count_rdata = 0, count = 0;
integer count_usb_check = 0; 

reg usb_status;

localparam IDLE = 2'b00, RESET = 2'b01, TRANSMIT_PATTERN = 2'b10, COMPARE = 2'b11;
reg     [1:0] state, next_state;

localparam PASS = 2'b00, FAIL = 2'b01;
reg		[1:0] spec_reg;

reg     [2:0] count_trans_state_t = 0, count_trans_state_r = 0;

reg 	[DATA_WIDTH-1:0] gpo;
reg     [DATA_WIDTH*2-1:0] fx3_dq_del;
wire	[DATA_WIDTH-1:0] gpo_in;


reg		intr_i = 1'b1;
reg     [1:0] intr_cdc;

//data pattern
reg 	[DATA_WIDTH-1:0] data [0:NUM_OF_TRANSACTION-1]; 

initial begin
	data[0] = 5;
	data[1] = 4;
	data[2] = 3;
	data[3] = 2;
end

BUFG BUFG_inst 
    (
        .O(clk_i),  // 1-bit output: Clock output
        .I(clk)     // 1-bit input: Clock input
    );

// xpm_cdc_async_rst #(
//       .DEST_SYNC_FF(4),    // DECIMAL; range: 2-10
//       .INIT_SYNC_FF(0),    // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
//       .RST_ACTIVE_HIGH(1)  // DECIMAL; 0=active low reset, 1=active high reset
//     )
//     xpm_cdc_async_rst_inst (
//       .dest_arst(rst_cdc),  // 1-bit output: src_arst asynchronous reset signal synchronized to destination
//       .dest_clk(clk_i),     // 1-bit input: Destination clock.
//       .src_arst(rst)        // 1-bit input: Source asynchronous reset signal.
//     );
 
    
    //RESET CDC
    always @(posedge clk_i)
    begin
        rst_cdc <= {rst_cdc[2:0], rst};
    end


    always @(posedge clk_i)
    begin
        if (rst_cdc[3])
            state <= RESET;
        else
            state <= next_state;
    end

    
    always @*
    begin
        case (state)
            IDLE    :   begin
                            if (rst_cdc[3]) 
                                next_state = RESET;
                            else if (count_trans_state_t == count_trans_state_r && count_trans_state_r < NUM_OF_TRANSACTION)
                                next_state = TRANSMIT_PATTERN;
                            else if (!ack)
                            	next_state = COMPARE;
                            else
                                next_state = IDLE;
                        end    
            RESET   : 
                        begin
                            if (reset_done_strb)
                                next_state = TRANSMIT_PATTERN;
                            else
                                next_state = RESET;
                        end
    TRANSMIT_PATTERN:   begin
                            if (count_tdata == NUM_OF_TRANSACTION + 1 && intr_i)
                                next_state = IDLE;
                            else
                                next_state = TRANSMIT_PATTERN;
                        end
        COMPARE     :   begin
                            if (count == NUM_OF_TRANSACTION)
                                next_state = IDLE;
                            else
                                next_state = COMPARE;
                        end
        endcase
    end



    always @(posedge clk_i)
    begin
        case(state)
        IDLE    : 
                    begin
                        count_rdata <= {32{1'b0}};
                        counter <= {32{1'b0}};
                        count_tdata <= {32{1'b0}};
                        count <= {32{1'b0}};
                    end
        RESET   :  
            		begin
                        counter <= counter + 1;
                     	if (counter < 200000/CLK_PERIOD)              
                            fx3_rst_i <= 1'b1;
                        else if (counter >= 200000/CLK_PERIOD)             
                            fx3_rst_i <= rst_cdc[3];
                    end          	
TRANSMIT_PATTERN :  	
					begin 
                        if (count_tdata != NUM_OF_TRANSACTION + 1) begin
                            count_tdata <= count_tdata + 1;
                            gpo <= data[count_tdata];
                            intr_i <= 1'b0;
                        end else 
                            intr_i <= 1'b1;
            		end	                       		
    	COMPARE :    
                    begin
                            count <= count + 1;
                            if (gpo_in == data[count]) begin
                                count_rdata <= count_rdata + 1;
                                //data_debug <= gpo_in;
                            end  
                        spec_reg <= (count_rdata == count) ? PASS : FAIL;
                    end
             endcase
          end        



    // USB status check
    always @(posedge clk_i)
    begin
        count_usb_check <= count_usb_check + 1;
            if (count_usb_check == USB_CHECK_PERIOD/CLK_PERIOD) begin
                usb_status <= gpi_status;
                count_usb_check <= 0;
            end   
    end    


    // Count number of trans state
    always @(rst_cdc[3], state)
    begin
        if (rst_cdc[3]) begin
            count_trans_state_t <= {3{1'b0}};
            count_trans_state_r <= {3{1'b0}};
        end else if (state == COMPARE) 
            count_trans_state_r <= count_trans_state_r + 1;
        else if (state == TRANSMIT_PATTERN)  
        	 count_trans_state_t <= count_trans_state_t + 1;
        else if ((count_trans_state_t && count_trans_state_r) == NUM_OF_TRANSACTION) begin
                count_trans_state_t <= count_trans_state_t;
                count_trans_state_r <= count_trans_state_r;
        	end    
    end

	
 
    always @(posedge clk_i)
    begin
        if (rst_cdc[3]) 
            fx3_dq_del <= {DATA_WIDTH*2{1'b0}};
        else begin  
            fx3_rst_z <= fx3_rst_i;  
            fx3_dq_del <= {fx3_dq_del[DATA_WIDTH-1:0], gpo};
        end
    end

    assign reset_done_strb = fx3_rst_z && (!fx3_rst_i); 


    always @(negedge clk_i or posedge rst)
    begin
        if (rst)
            intr_cdc <= {2{1'b0}};
        else
            intr_cdc <= {intr_cdc[0], intr_i};
    end




    assign intr = intr_cdc[1];
    assign fx3_dq = !intr_cdc[1] ? fx3_dq_del[DATA_WIDTH*2-1:DATA_WIDTH] : {DATA_WIDTH{1'bZ}};
    assign gpo_in = fx3_dq;
    assign fx3_pclk = clk_i;
    assign fx3_rst = fx3_rst_i;


endmodule
