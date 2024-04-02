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
    parameter PATH = "./";

    /* Until app parser is added */
    /* verilator lint_off UNUSEDPARAM */
    parameter SIM_FREQ = 100_000_000;
    /* verilator lint_on UNUSEDPARAM */

endpackage
