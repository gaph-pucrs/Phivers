`include "../TaskInjector/rtl/TaskInjectorPkg.sv"

module Debug 
    import TaskInjectorPkg::*;
#(
    parameter logic [15:0] ADDRESS          = 16'h0000,
    parameter logic [15:0] SEQ_ADDR         = 16'h0000,
    parameter bit          UART_DEBUG       = 1,
    parameter bit          SCHED_DEBUG      = 1,
    parameter bit          PIPE_DEBUG       = 1,
    parameter bit          TRAFFIC_DEBUG    = 1,
    parameter string       DBG_SCHED_FILE   = "./debug/scheduling_report.txt",
    parameter string       DBG_TRAFFIC_FILE = "./debug/traffic_router.txt"
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

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (rst_ni) begin
            if (en_i && we_i && addr_i == 24'h000004) begin
                $display("[%7.3f] [ PE %02xx%02x] Simulation halted", $time()/1_000_000.0, ADDRESS[15:8], ADDRESS[7:0]);
                $finish();
            end
        end
    end

    if (UART_DEBUG) begin : gen_uart_dbg
        int log_fd;

        initial begin
            log_fd = $fopen($sformatf("log/log%0dx%0d.txt", ADDRESS[15:8], ADDRESS[7:0]), "w");
            if (log_fd == '0) begin
                $display("[Debug] Could not open log file");
                $finish();
            end
        end

        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (rst_ni) begin
                if(en_i && we_i && addr_i == 24'h000000) begin
                    // if (data_i[7:0] == 8'h0A)
                    //     $fwrite(log_fd, "__$$__%0d", $time());

                    $fwrite(log_fd, "%c", data_i[7:0]);

                    if (data_i[7:0] == 8'h0A)
                        $fflush(log_fd);
                end
            end
        end

        final begin
            $fclose(log_fd);
        end
    end

    if (SCHED_DEBUG) begin : gen_sched_dbg
        int sched_fd;
        
        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (rst_ni) begin
                if (en_i && we_i && addr_i == 24'h000010) begin
                    /* Ugly, but it is how the graphical debugger is implemented */
                    /* verilator lint_off BLKSEQ */
                    sched_fd = $fopen(DBG_SCHED_FILE, "a");
                    /* verilator lint_on BLKSEQ */
                    if (sched_fd == '0) begin
                        $display("[Debug] Could not open sched log file");
                        $finish();
                    end
                    else begin
                        $fwrite(sched_fd, "%0d\t%0d\t%0d\n", ADDRESS, data_i, tick_cntr_i);
                    end
                    $fflush(sched_fd);
                    $fclose(sched_fd);
                end                    
            end
        end
    end

    if (PIPE_DEBUG) begin : gen_pipe_dbg
        int av_fd;
        int req_fd;
        int pipe_fd;

        initial begin
            av_fd = $fopen($sformatf("debug/available/%0d.txt", SEQ_ADDR), "w");
            if (av_fd == '0) begin
                $display("[Debug] Could not open data available debug file");
                $finish();
            end

            req_fd = $fopen($sformatf("debug/request/%0d.txt", SEQ_ADDR), "w");
            if (req_fd == '0) begin
                $display("[Debug] Could not open message request debug file");
                $finish();
            end

            pipe_fd = $fopen($sformatf("debug/pipe/%0d.txt", SEQ_ADDR), "w");
            if (pipe_fd == '0) begin
                $display("[Debug] Could not open message delivery debug file");
                $finish();
            end
        end

        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (rst_ni) begin
                if(en_i && we_i) begin
                    case (addr_i)
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
        end

        final begin
            $fclose(av_fd);
            $fclose(req_fd);
            $fclose(pipe_fd);
        end
    end

    if (TRAFFIC_DEBUG) begin : gen_traffic_dbg
        int traffic_fd;
        
        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (rst_ni) begin
                if (en_i && we_i && addr_i == 24'h000008) begin
                    /* Ugly, but it is how the graphical debugger is implemented */
                    /* verilator lint_off BLKSEQ */
                    traffic_fd = $fopen(DBG_TRAFFIC_FILE, "a");
                    /* verilator lint_on BLKSEQ */
                    if (traffic_fd == '0) begin
                        $display("[Debug] Could not open traffic log file");
                        $finish();
                    end
                    else begin
                        $fwrite(
                            traffic_fd, 
                            "%0d\t%0d\t%0x\t%0d\t%0d\t%0d\t%0d\t%0d\n", 
                            tick_cntr_i,
                            ADDRESS, 
                            TASK_TERMINATED, 
                            0, 
                            0, 
                            8, 
                            -1,
                            data_i[15:0]
                        );
                    end
                    $fflush(traffic_fd);
                    $fclose(traffic_fd);
                end                    
            end
        end
    end

endmodule
