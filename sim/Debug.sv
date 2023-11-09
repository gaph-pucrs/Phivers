module Debug 
#(
    parameter logic [15:0] ADDRESS
)
(
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic        en_i,
    input  logic        we_i,
    input  logic [23:0] addr_i,
    input  logic [31:0] data_i
);
    int fd;

    initial begin
        fd = $fopen($sformatf("log%0ux%0u.txt", ADDRESS[15:8], ADDRESS[7:0]), "w");
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (rst_ni && en_i && we_i) begin
            case (addr_i)
                24'h000000: $fwrite(fd, "%c", data_i);
                default: ;
            endcase
        end
    end

endmodule
