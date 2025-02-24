/// DRAM module parameters
`define     BANK_NUM        4

`define     DATA_WIDTH      16
// two byte a time so indexing is done for 2048 bytes in a row
`define     COL_NUM         16384  

`define     ROW_NUM         8192

// SDRAM controller
`define     BA_WIDTH        $clog2(`BANK_NUM)

`define     ADDR_WIDTH      $clog2(`ROW_NUM)

`define     COL_ADDR_WIDTH  $clog2(`COL_NUM  / `DATA_WIDTH)

`define     DQM_WIDTH       (`DATA_WIDTH/8)

