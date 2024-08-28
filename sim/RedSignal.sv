module RedSignal
#(
    parameter logic [15:0] ADDRESS  = 16'b0,
    parameter string       PORT     = ""
)
(
    input  logic clk_i,
    input  logic rst_ni,

    input  logic tx_i,
    output logic cr_tx_o,
    input  logic eop_tx_i,

    output logic rx_o,
    input  logic cr_rx_i
);

    int unsigned tick_begin;
    int unsigned interval_min;
    int unsigned interval_max;
    int unsigned cycles_min;
    int unsigned cycles_max;

    int cfg;
    initial begin
        cfg = $fopen($sformatf("../link/rs%0dx%0d-%s.cfg", ADDRESS[15:8], ADDRESS[7:0], PORT), "r");
        if (cfg == '0) begin
            $display(
                "[%7.3f] [RS %02dx%02d-%s] Could not open configuration file", 
                $time()/1_000_000.0, 
                ADDRESS[15:8], 
                ADDRESS[7:0], 
                PORT
            );
            $finish();
        end
        else begin
            $fscanf(cfg, "%d", tick_begin  );
            $fscanf(cfg, "%d", interval_min);
            $fscanf(cfg, "%d", interval_max);
            $fscanf(cfg, "%d", cycles_min  );
            $fscanf(cfg, "%d", cycles_max  );
            $fclose(cfg);

            $display(
                "[%7.3f] [RS %02dx%02d-%s] Will hang for %0d to %0d cycles every %0d to %0d packets", 
                $time()/1_000_000.0, 
                ADDRESS[15:8], 
                ADDRESS[7:0], 
                PORT,
                cycles_min,
                cycles_max,
                interval_min,
                interval_max
            );
        end
    end

    typedef enum {
        IDLE,
        EOP,
        MALICIOUS,
        PASSTHROUGH,
        HANG
    } rs_fsm_t;

    rs_fsm_t state;
    rs_fsm_t next_state;

    int unsigned next_hang;
    int unsigned hang_cycles;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            next_hang <= $urandom_range(interval_min, interval_max);
        end
        else if (state == EOP) begin
            if(next_hang == 0)
                next_hang <= $urandom_range(interval_min, interval_max);
            else
                next_hang <= next_hang - 1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            hang_cycles <= 0;
        else if (state == MALICIOUS)
            hang_cycles <= $urandom_range(cycles_min, cycles_max);
        else if (state == HANG && tx_i && cr_rx_i)
            hang_cycles <= hang_cycles - 1;
    end

    always_comb begin
        case (state)
            EOP,
            IDLE: begin
                if (tx_i && $time() > 64'(tick_begin)) begin
                    if (eop_tx_i && cr_rx_i)
                        next_state = EOP;
                    else if (next_hang == 0) begin
                        next_state = MALICIOUS;
                        $display(
                            "[%7.3f] [RS %02dx%02d-%s] Entering malicious state", 
                            $time()/1_000_000.0, 
                            ADDRESS[15:8], 
                            ADDRESS[7:0], 
                            PORT
                        );
                    end
                    else
                        next_state = PASSTHROUGH;
                end
                else begin
                    next_state = IDLE;
                end
            end
            PASSTHROUGH: begin
                next_state = !(tx_i && eop_tx_i && cr_rx_i)
                    ? PASSTHROUGH
                    : EOP;
            end
            MALICIOUS: begin
                next_state = !(tx_i && eop_tx_i && cr_rx_i)
                    ? HANG
                    : EOP;
            end
            HANG: begin
                if (hang_cycles == 0)
                    next_state = PASSTHROUGH;
                else
                    next_state = HANG;
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            state <= IDLE;
        else 
            state <= next_state;
    end

    logic block;
    assign block = (state == HANG);

    always_comb begin
        if (!block) begin
            rx_o    = tx_i;
            cr_tx_o = cr_rx_i;
        end
        else begin
            rx_o    = '0;
            cr_tx_o = '0;
        end
    end

endmodule
