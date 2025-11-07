package esp_apb_pkg;
  typedef struct packed {
    logic [31:0] paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [2:0]  pprot;
    logic [31:0] pwdata;
    logic [3:0]  pstrb;
  } apb_req_t;

  typedef struct packed {
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;
  } apb_rsp_t;
endpackage
