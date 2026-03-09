

module FIR_top (
    input  wire         rst_n,
    input  wire         clk1,
    input  wire         clk2,

    // input stream (clk1 domain)
    input  wire         valid_in,
    input  wire signed [15:0] din,

    // coefficient load (clk2 domain) - TB controls address + data + valid
    input  wire         cload,        // 1: preload coefficients
    input  wire [5:0]   caddr,        // TB: coefficient address (0..63)
    input  wire [15:0]  cin,          // TB: coefficient data

    output wire signed [15:0] dout,
    output wire               valid_out,
    output wire               done
);

    // ============================================================
    // FIFO wires
    // ============================================================
    wire [15:0]dout_inner;
    wire        fifo_full, fifo_empty;
    wire [15:0] fifo_dout;

    // FSM controls
    wire FIFO_we;   // kept for compatibility (NOT used to write CDC FIFO)
    wire FIFO_re;
    wire MEM_re, MEM_we;
    wire shift_en;
    wire REG_re, REG_we;
    wire ACC_en;
    wire END;
    assign done = END;

    // CMEM / shift / ALU
    wire [15:0] cmem_dout;
    wire [15:0] x_dout;

    // CNT_64 comes from ALU in your design
    wire [6:0] CNT_64;
    wire [5:0] tap_addr = CNT_64[5:0];

    // ============================================================
    // CDC FIFO write enable (clk1 domain)
    // ============================================================
    wire fifo_we_clk1 = valid_in && !fifo_full;

    // ============================================================
    // FSM (clk2 domain)
    // ============================================================
    wire [13:0]CNT_10000;
    FSM u_fsm (
        .clk        (clk2),
        .rst_n      (rst_n),
        .valid_in   (valid_in),      
        .cload      (cload),
        .FIFO_empty (fifo_empty),
        .FIFO_full  (fifo_full),
        .CNT_64     (CNT_64),

        .FIFO_we    (FIFO_we),
        .FIFO_re    (FIFO_re),
        .MEM_re     (MEM_re),
        .MEM_we     (MEM_we),
        .shift_en   (shift_en),
        .REG_re     (REG_re),
        .REG_we     (REG_we),
        .ACC_en     (ACC_en),
        .CNT_10000  (CNT_10000),
        .END        (END)
    );

    // ============================================================
    // CDC FIFO (clk1 write, clk2 read)
    // ============================================================
    CDC_FIFO u_fifo (
        .rst_n (rst_n),

        .clk1  (clk1),
        .we    (fifo_we_clk1),
        .din   (din),

        .clk2  (clk2),
        .re    (FIFO_re),

        .dout  (fifo_dout),
        .full  (fifo_full),
        .empty (fifo_empty)
    );

    // ============================================================
    // CMEM address control (TB controls write address)
    // - cload=1: use TB caddr for writing coefficients
    // - cload=0: use tap_addr for reading coefficients during MAC
    // ============================================================
    wire [5:0] cmem_addr = (cload) ? caddr : tap_addr;

    // write enable: only write during preload + FSM允许写 + TB声明有效
    wire cmem_we = cload && MEM_we;

    // read enable during MAC (if your CMEM uses re)
    wire cmem_re = (!cload) && MEM_re;

    CMEM u_cmem (
        .clk   (clk2),
        .rst_n (rst_n),
        .we    (cmem_we),
        .re    (cmem_re),
        .addr  (cmem_addr),
        .din   (cin),
        .dout  (cmem_dout)
    );

    // ============================================================
    // shift_reg address control
    // Requirement: always write new sample to index 0, then shift upward
    // - when REG_we=1 => addr=0
    // - when reading taps => addr=tap_addr
    // ============================================================
    wire [5:0] shift_addr = (REG_we) ? 6'd0 : tap_addr;

    shift_reg u_shift (
        .clk  (clk2),
        .rst_n(rst_n),
        .Din  (fifo_dout),
        .we   (REG_we),
        .se   (shift_en),
        .re   (REG_re),
        .addr (shift_addr),
        .Dout (x_dout)
    );

    // ============================================================
    // ALU: MAC/ACC (drives CNT_64)
    // ============================================================
    ALU u_alu (
        .Din     (x_dout),
        .Cin     (cmem_dout),
        .clk     (clk2),
        .EN_cal  (ACC_en),
        .rst_n   (rst_n),
        .Dout    (dout_inner),
        .CNT_mac (CNT_64)
    );

    // ============================================================
    // output valid (SHIFT cycle)
    // ============================================================
    assign valid_out = shift_en;
    assign dout=(valid_out)?dout_inner:dout;

endmodule

