package reg_pkg;
    localparam int DATA_WIDTH = 32;
    localparam int ADDR_WIDTH = 64;

    typedef struct packed {
        logic        valid;
        logic        write;
        logic [DATA_WIDTH/8-1:0] wstrb;
        logic [ADDR_WIDTH-1:0] addr;
        logic [DATA_WIDTH-1:0] wdata;
    } reg_req_t;

    typedef struct packed {
        logic        error;
        logic        ready;
        logic [DATA_WIDTH-1:0] rdata;
    } reg_rsp_t;
endpackage