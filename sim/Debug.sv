`include "../TaskInjector/rtl/TaskInjectorPkg.sv"
/* Debug switches: macros, as this module is bound from the testbench */
`include "PhiversPkg.sv"

module Debug 
    import TaskInjectorPkg::*;
#(
    parameter logic [15:0] ADDRESS          = 16'h0000,
    /* Only read by the optional features */
    /* verilator lint_off UNUSEDPARAM */
    parameter logic [15:0] SEQ_ADDR         = 16'h0000,
    parameter string       DBG_SCHED_FILE   = "./debug/scheduling_report.txt",
    parameter string       DBG_TRAFFIC_FILE = "./debug/traffic_router.txt"
    /* verilator lint_on UNUSEDPARAM */
)
(
    input  logic        clk_i,
    input  logic        rst_ni,

    /* Monitors the CPU OBI data interface: writes to [0xF0000000, 0xF1000000[ */
    input  logic        req_i,
    input  logic        gnt_i,
    input  logic        we_i,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,   /* Only read by the optional features */
    /* verilator lint_on UNUSEDSIGNAL */

    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [63:0] tick_cntr_i
    /* verilator lint_on UNUSEDSIGNAL */
);

    logic en;
    assign en = req_i && gnt_i && (addr_i[31:28] == 4'hF);

    logic [23:0] addr;
    assign addr = addr_i[23:0];

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (rst_ni) begin
            if (en && we_i && addr == 24'h000004) begin
                $display("[%7.3f] [  PE %02dx%02d] Simulation halted", $time()/1_000_000.0, ADDRESS[15:8], ADDRESS[7:0]);
                $finish();
            end
        end
    end

`ifdef UART_DEBUG
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
            if(en && we_i && addr == 24'h000000) begin
                $fwrite(log_fd, "%c", wdata_i[7:0]);

                if (wdata_i[7:0] == 8'h0A)
                    $fflush(log_fd);
            end
        end
    end

    final begin
        $fclose(log_fd);
    end
`endif

`ifdef SCHED_DEBUG
    int sched_fd;
    
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (rst_ni) begin
            if (en && we_i && addr == 24'h000010) begin
                /* Ugly, but it is how the graphical debugger is implemented */
                /* verilator lint_off BLKSEQ */
                sched_fd = $fopen(DBG_SCHED_FILE, "a");
                /* verilator lint_on BLKSEQ */
                if (sched_fd == '0) begin
                    $display("[Debug] Could not open sched log file");
                    $finish();
                end
                else begin
                    $fwrite(sched_fd, "%0d\t%0d\t%0d\n", ADDRESS, wdata_i, tick_cntr_i);
                end
                $fflush(sched_fd);
                $fclose(sched_fd);
            end                    
        end
    end
`endif

`ifdef PIPE_DEBUG
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
            if(en && we_i) begin
                case (addr)
                    24'h000020: begin
                        $fwrite(pipe_fd, "add\t%0d\t%0d\t%0d\n", wdata_i[31:16], wdata_i[15:0], tick_cntr_i);
                        $fflush(pipe_fd);
                    end
                    24'h000024: begin
                        $fwrite(pipe_fd, "rem\t%0d\t%0d\t%0d\n", wdata_i[31:16], wdata_i[15:0], tick_cntr_i);
                        $fflush(pipe_fd);
                    end
                    24'h000030: begin
                        $fwrite(req_fd, "add\t%0d\t%0d\t%0d\n", wdata_i[31:16], wdata_i[15:0], tick_cntr_i);
                        $fflush(req_fd);
                    end
                    24'h000034: begin
                        $fwrite(req_fd, "rem\t%0d\t%0d\t%0d\n", wdata_i[31:16], wdata_i[15:0], tick_cntr_i);
                        $fflush(req_fd);
                    end
                    24'h000040: begin
                        $fwrite(av_fd, "add\t%0d\t%0d\t%0d\n", wdata_i[31:16], wdata_i[15:0], tick_cntr_i);
                        $fflush(av_fd);
                    end
                    24'h000044: begin
                        $fwrite(av_fd, "rem\t%0d\t%0d\t%0d\n", wdata_i[31:16], wdata_i[15:0], tick_cntr_i);
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
`endif

`ifdef TRAFFIC_DEBUG
    int traffic_fd;
    
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (rst_ni) begin
            if (en && we_i && addr == 24'h000008) begin
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
                        wdata_i[15:0]
                    );
                end
                $fflush(traffic_fd);
                $fclose(traffic_fd);
            end                    
        end
    end
`endif

`ifdef SAFE_DEBUG
    int safe_fd;

    initial begin
        safe_fd = $fopen($sformatf("debug/safe/%0dx%0d.txt", ADDRESS[15:8], ADDRESS[7:0]), "w");
        if (safe_fd == '0) begin
            $display("[Debug] Could not open safe file");
            $finish();
        end
        else begin
            $fwrite(safe_fd, "snd_time,inf_time,prod,cons,inf_lat,lat_pred,lat_mon\n");
        end
    end

    logic [31:0] safe_snd_time;
    logic [31:0] safe_inf_time;
    logic [31:0] safe_edge;
    logic [31:0] safe_inf_lat;
    logic [31:0] safe_lat_pred;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (rst_ni) begin
            if (en && we_i) begin
                case (addr)
                    24'h000050: safe_snd_time <= wdata_i;
                    24'h000054: safe_inf_time <= wdata_i;
                    24'h000058: safe_edge     <= wdata_i;
                    24'h00005C: safe_inf_lat  <= wdata_i;
                    24'h000060: safe_lat_pred <= wdata_i;
                    24'h000064:
                        // snd_time,inf_time,prod,cons,inf_lat,lat_pred,lat_mon
                        $fwrite(
                            safe_fd, 
                            "%0d,%0d,%0d,%0d,%0d,%0d,%0d\n", 
                            safe_snd_time,
                            safe_inf_time,
                            safe_edge >> 16,
                            safe_edge & 32'h0000FFFF,
                            safe_inf_lat,
                            safe_lat_pred,
                            wdata_i // lat_mon
                        );
                endcase
            end
        end
    end

    final begin
        $fclose(safe_fd);
    end
`endif

endmodule
