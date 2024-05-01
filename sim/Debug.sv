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

    /* For now, only the LSB is used */
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] data_i
    /* verilator lint_on UNUSEDSIGNAL */
);
    int fd;

    initial begin
        fd = $fopen($sformatf("log/log%0dx%0d.txt", ADDRESS[15:8], ADDRESS[7:0]), "w");
        if (fd == '0) begin
            $display("[Debug] Could not open log file");
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (rst_ni && en_i && we_i) begin
            case (addr_i)
                24'h000000: begin
                    $fwrite(fd, "%c", data_i[7:0]);
                    if (data_i[7:0] == 8'h0A) begin
                        $fflush(fd);
                    end
                end
                24'h000004: begin
                    $display("[%7.3f] [ PE %02xx%02x] Simulation halted", $time()/1_000_000.0, ADDRESS[15:8], ADDRESS[7:0]);
                    $finish();
                end
                default: ;
            endcase
        end
    end

    final begin
        $fclose(fd);
    end

endmodule
