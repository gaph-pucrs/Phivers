`timescale 1ns/1ns

module TopTB
(
);

    logic clk = 1'b1;
    logic rst_n;

    always begin
        #5.0 clk <= 0;
        #5.0 clk <= 1;
    end

    initial begin
        rst_n = 1'b0;
        
        #100 rst_n = 1'b1;
    end

    PhiversTB tb(
        .clk(clk),
        .rst_n(rst_n)
    );

endmodule
