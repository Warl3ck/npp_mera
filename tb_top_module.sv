`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.01.2023 21:53:01
// Design Name: 
// Module Name: tb_top_module
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

module tb_top_module(
);

parameter CLK_PERIOD = 25ns;
parameter DATA_WIDTH = 32;
parameter NUM_OF_TRANSACTION = 4;
parameter USB_CHECK_PERIOD = 100000;

// model delay cycles of fifo loopback
localparam NUM_CYCLE_DELAY = 8;

bit clk = 1'b0;
bit rst;
bit intr;
bit gpi_status;

bit [NUM_CYCLE_DELAY-1:0] intr_reg = 8'hFF;

wire [DATA_WIDTH-1:0] data_i; 
bit [DATA_WIDTH*NUM_CYCLE_DELAY-1:0] data_z; //[0:3];

bit reset_done;

integer count_trans = 0;

always #(CLK_PERIOD/2) clk <= ~clk;




initial begin
	reset_done = 1'b0;
    rst = 1'b0;
    #101ns
    @(negedge clk)
    rst <= 1'b1;
    #50ns
    rst <= 1'b0;
    wait (count_trans == NUM_OF_TRANSACTION);
    #20us
    rst = 1'b1;
    #250us;
    rst = 1'b0;
    @(posedge clk)
	reset_done = 1'b1;
end

initial begin
    gpi_status = 1'b0;
    #40us
    gpi_status = 1'b1;
    #140us
    gpi_status = 1'b0;
end


always_ff @(negedge clk)
begin
    intr_reg <= {intr_reg[NUM_CYCLE_DELAY-2:0], intr};
end

always @(posedge clk)
begin
	if (reset_done)
		data_z <= {data_z[(DATA_WIDTH*NUM_CYCLE_DELAY-1)-(DATA_WIDTH-1)-1:0], data_i+2}; // model fail state for special reg
	else
    	data_z <= {data_z[(DATA_WIDTH*NUM_CYCLE_DELAY-1)-(DATA_WIDTH-1)-1:0], data_i};
end

assign data_i = !intr_reg[NUM_CYCLE_DELAY-1] ? data_z[DATA_WIDTH*NUM_CYCLE_DELAY-1:DATA_WIDTH*NUM_CYCLE_DELAY-DATA_WIDTH] : {DATA_WIDTH{1'bZ}}; 


always @(intr)
begin
	if (!intr)
		count_trans = count_trans + 1;
end

    top_module #(.CLK_PERIOD(CLK_PERIOD), .DATA_WIDTH(DATA_WIDTH), .NUM_OF_TRANSACTION(NUM_OF_TRANSACTION), .USB_CHECK_PERIOD(USB_CHECK_PERIOD)) 
    top_module_inst
    (
        .clk        (clk),
        .rst        (rst),
        .ack        (intr_reg[7]),
        .fx3_pclk   (),   // 40 MHz
        .fx3_rst    (),    // reset active high
        .fx3_dq		(data_i),
        .intr       (intr),
        //
        .gpi_status (gpi_status)
    );
    

//initial begin
//	#200400
//    if (!intr)
////    $display(intr_reg);
//    for (int i = 0; i < 2; i++) begin
//    	@(negedge clk)
//    	dat_debug.push_back(data_i);
//        $display(dat_debug);
//    end
//end
    



endmodule
