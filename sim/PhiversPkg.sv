`ifndef PHIVERS_PKG
`define PHIVERS_PKG

`include "../Hermes/rtl/HermesPkg.sv"

package PhiversPkg;

    import HermesPkg::*;

    parameter N_PE_X = 2;
    parameter N_PE_Y = 2;
    parameter TASKS_PER_PE = 1;
    parameter logic [15:0] ADDR_MA_INJ = 16'h0000;
    parameter hermes_port_t PORT_MA_INJ = HERMES_SOUTH;
    parameter logic [15:0] ADDR_APP_INJ = 16'h0101;
    parameter hermes_port_t PORT_APP_INJ = HERMES_NORTH;
    parameter IMEM_PAGE_SZ = 32768;
    parameter DMEM_PAGE_SZ = 32768;
    parameter UART_DEBUG = 1;
    parameter SCHED_DEBUG = 1;
    parameter PIPE_DEBUG = 1;
    parameter TRAFFIC_DEBUG = 1;

endpackage

`endif
