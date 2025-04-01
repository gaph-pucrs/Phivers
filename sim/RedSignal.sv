module RedSignal
#(
    parameter logic [15:0] ADDRESS  = 16'b0,
    parameter string       PORT     = ""
)
(
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic        tx_i,
    output logic        cr_tx_o,
    input  logic        eop_tx_i,
    input  logic [31:0] data_tx_i,

    output logic        rx_o,
    input  logic        cr_rx_i
);

    bit enabled;
    int unsigned tick_begin;
    int unsigned cycles_min;
    int unsigned cycles_max;
    int unsigned chance;

    int cfg;
    int log;
    initial begin
        cfg = $fopen($sformatf("link/rs%0dx%0d-%s.cfg", ADDRESS[15:8], ADDRESS[7:0], PORT), "r");
        if (cfg == '0) begin
            $display(
                "[%7.3f] [RS %02dx%02d-%s] Could not open configuration file. Disabling.", 
                $time()/1_000_000.0, 
                ADDRESS[15:8], 
                ADDRESS[7:0], 
                PORT
            );
            enabled = 0;
        end
        else begin
            enabled = 1;
            $fscanf(cfg, "%d", tick_begin);
            $fscanf(cfg, "%d", cycles_min);
            $fscanf(cfg, "%d", cycles_max);
            $fscanf(cfg, "%d", chance    );
            $fclose(cfg);

            log = $fopen($sformatf("debug/link/rs%0dx%0d-%s.log", ADDRESS[15:8], ADDRESS[7:0], PORT), "w");
            $fwrite(log, "timestamp,prod,cons,cycles\n");

            $display(
                "[%7.3f] [RS %02dx%02d-%s] Will hang for %0d to %0d cycles with %0d chance", 
                $time()/1_000_000.0, 
                ADDRESS[15:8], 
                ADDRESS[7:0], 
                PORT,
                cycles_min,
                cycles_max,
                chance
            );
        end
    end

    typedef enum {
        HEADER,
        SIZE,
        SERVICE,
        PROD,
        CONS,
        SRCPE,
        TIMESTAMP,
        LOG, 
        HANG,
        NEXT,
        EOP
    } rs_fsm_t;

    logic received;
    assign received = tx_i && cr_rx_i;

    rs_fsm_t state;
    rs_fsm_t next_state;

    int unsigned next_hang;
    int unsigned hang_cycles;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            next_hang <= $urandom_range(0, 99);
        else if (state == NEXT)
            next_hang <= $urandom_range(0, 99);
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            hang_cycles <= $urandom_range(cycles_min, cycles_max);
        else begin
            case (state)
                NEXT:      hang_cycles <= (next_hang < chance) ? $urandom_range(cycles_min, cycles_max) : hang_cycles;
                HANG:      hang_cycles <= received             ? (hang_cycles - 1)                      : hang_cycles;
                default:   ;
            endcase
        end
    end

    always_comb begin
        case (state)
            HEADER:  begin
                if (received)
                    next_state = ($time() >= 64'(tick_begin)) ? SIZE : EOP;
                else
                    next_state = HEADER;
            end
            SIZE:    next_state = received ? SERVICE : SIZE;
            SERVICE: begin
                if (received) begin
                    if (data_tx_i == 32'h00000001)
                        next_state = (next_hang < chance) ? PROD : NEXT;
                    else
                        next_state = EOP;
                end
                else begin
                    next_state = SERVICE;
                end
            end
            PROD:      next_state = received               ? CONS      : PROD;
            CONS:      next_state = received               ? SRCPE     : CONS;
            SRCPE:     next_state = received               ? TIMESTAMP : SRCPE;
            TIMESTAMP: next_state = received               ? LOG       : HANG;
            LOG:       next_state = HANG;
            HANG:      next_state = (hang_cycles == 0)     ? NEXT      : HANG;
            NEXT:      next_state = EOP;
            EOP:       next_state = (received && eop_tx_i) ? HEADER    : EOP;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            state <= HEADER;
        else if (enabled)
            state <= next_state;
    end

    logic [31:0] producer;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            producer <= '0;
        else if (state == PROD)
            producer <= data_tx_i;
    end

    logic [31:0] consumer;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            consumer <= '0;
        else if (state == CONS)
            consumer <= data_tx_i;
    end

    logic [31:0] timestamp;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            timestamp <= '0;
        else if (state == TIMESTAMP)
            timestamp <= data_tx_i;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ;
        end
        else if (state == LOG) begin
            $fwrite(
                log, 
                "%0d,%0d,%0d,%0d\n",
                timestamp, 
                producer, 
                consumer, 
                hang_cycles
            );
        end
    end

    always_comb begin
        if (state != HANG) begin
            rx_o    = tx_i;
            cr_tx_o = cr_rx_i;
        end
        else begin
            rx_o    = '0;
            cr_tx_o = '0;
        end
    end

    final begin
        $fclose(log);
    end

endmodule
