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

    int unsigned tick_begin;
    int unsigned cycles_min;
    int unsigned cycles_max;
    int unsigned chance;

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
            $fscanf(cfg, "%d", tick_begin);
            $fscanf(cfg, "%d", cycles_min);
            $fscanf(cfg, "%d", cycles_max);
            $fscanf(cfg, "%d", chance    );
            $fclose(cfg);

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
        if (!rst_ni) begin
            next_hang <= $urandom_range(0, 99);
        end
        else if (state == NEXT) begin
            next_hang <= $urandom_range(0, 99);
        end
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
                    if (data_tx_i == 32'h00000001) begin
                        if (next_hang < chance) begin
                            next_state = HANG;
                            $display(
                                "[%7.3f] [RS %02dx%02d-%s] Entering malicious state for %0d cycles", 
                                $time()/1_000_000.0, 
                                ADDRESS[15:8], 
                                ADDRESS[7:0], 
                                PORT, 
                                hang_cycles
                            );
                        end
                        else begin
                            next_state = NEXT;
                        end
                    end
                    else begin
                        next_state = EOP;
                    end
                end
                else begin
                    next_state = SERVICE;
                end
            end
            HANG: next_state = (hang_cycles == 0)     ? NEXT   : HANG;
            NEXT: next_state = EOP;
            EOP:  next_state = (received && eop_tx_i) ? HEADER : EOP;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            state <= HEADER;
        else 
            state <= next_state;
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

endmodule
