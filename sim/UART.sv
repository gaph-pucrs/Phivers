module UART 
#(
    parameter FILE = "log.txt"
)
(
    input  logic       clk_i,
    input  logic       rst_ni,

    input  logic       en_i,
    input  logic       we_i,
    input  logic [7:0] data_i
);
    int fd;

    initial begin
        fd = $fopen(FILE, "w");
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (rst_ni && en_i && we_i)
            $fwrite(fd, "%c", data_i);
    end

endmodule
