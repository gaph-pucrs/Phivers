module Debug 
#(
    parameter logic [15:0] ADDRESS,
    parameter logic [15:0] SEQ_ADDR,
    parameter string       DBG_SCHED_FILE = "./debug/scheduling_report.txt"
)
(
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic        en_i,
    input  logic        we_i,
    input  logic [23:0] addr_i,
    input  logic [31:0] data_i,

    input  logic [63:0] tick_cntr_i
);
    int log_fd;
    
    int sched_fd;

    int av_fd;
    int req_fd;
    int pipe_fd;

    initial begin
        log_fd = $fopen($sformatf("log/log%0dx%0d.txt", ADDRESS[15:8], ADDRESS[7:0]), "w");
        if (log_fd == '0) begin
            $display("[Debug] Could not open log file");
        end

        av_fd = $fopen($sformatf("debug/available/%0d.txt", SEQ_ADDR), "w");
        if (av_fd == '0) begin
            $display("[Debug] Could not open data available debug file");
        end

        req_fd = $fopen($sformatf("debug/request/%0d.txt", SEQ_ADDR), "w");
        if (req_fd == '0) begin
            $display("[Debug] Could not open message request debug file");
        end

        pipe_fd = $fopen($sformatf("debug/pipe/%0d.txt", SEQ_ADDR), "w");
        if (pipe_fd == '0) begin
            $display("[Debug] Could not open message request debug file");
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (rst_ni && en_i && we_i) begin
            case (addr_i)
                24'h000000: begin
                    $fwrite(log_fd, "%c", data_i[7:0]);
                    if (data_i[7:0] == 8'h0A) begin
                        $fflush(log_fd);
                    end
                end
                24'h000004: begin
                    $display("[%7.3f] [ PE %02xx%02x] Simulation halted", $time()/1_000_000.0, ADDRESS[15:8], ADDRESS[7:0]);
                    $finish();
                end
                24'h000010: begin
                    /* Ugly, but it is how the graphical debugger is implemented */
                    /* verilator lint_off BLKSEQ */
                    sched_fd = $fopen(DBG_SCHED_FILE, "a");
                    /* verilator lint_on BLKSEQ */
                    if (sched_fd == '0) begin
                        $display("[Debug] Could not open sched log file");
                    end
                    else begin
                        $fwrite(sched_fd, "%0d\t%0d\t%0d\n", ADDRESS, data_i, tick_cntr_i);
                    end
                    $fflush(sched_fd);
                    $fclose(sched_fd);
                end
                24'h000020: begin
                    $fwrite(pipe_fd, "add\t%0d\t%0d\t%0d\n", data_i[31:16], data_i[15:0], tick_cntr_i);
                    $fflush(pipe_fd);
                end
                24'h000024: begin
                    $fwrite(pipe_fd, "rem\t%0d\t%0d\t%0d\n", data_i[31:16], data_i[15:0], tick_cntr_i);
                    $fflush(pipe_fd);
                end
                24'h000030: begin
                    $fwrite(req_fd, "add\t%0d\t%0d\t%0d\n", data_i[31:16], data_i[15:0], tick_cntr_i);
                    $fflush(req_fd);
                end
                24'h000034: begin
                    $fwrite(req_fd, "rem\t%0d\t%0d\t%0d\n", data_i[31:16], data_i[15:0], tick_cntr_i);
                    $fflush(req_fd);
                end
                24'h000040: begin
                    $fwrite(av_fd, "add\t%0d\t%0d\t%0d\n", data_i[31:16], data_i[15:0], tick_cntr_i);
                    $fflush(av_fd);
                end
                24'h000044: begin
                    $fwrite(av_fd, "rem\t%0d\t%0d\t%0d\n", data_i[31:16], data_i[15:0], tick_cntr_i);
                    $fflush(av_fd);
                end
                default: ;
            endcase
        end
    end

    final begin
        $fclose(log_fd);
        $fclose(av_fd);
        $fclose(req_fd);
        $fclose(pipe_fd);
    end

endmodule
