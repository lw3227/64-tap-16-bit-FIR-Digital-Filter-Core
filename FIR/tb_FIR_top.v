`timescale 1ns/1ps

module tb_FIR_top;

  // ----------------------------
  // Parameters
  // ----------------------------
  localparam integer N_COEF = 64;
  localparam integer N_SAMP = 10000;

  // clk1 = 10kHz => period 100us = 100_000ns
  // clk2 = 1MHz  => period 1us   = 1_000ns
  localparam integer CLK1_HALF = 50000; // ns
  localparam integer CLK2_HALF =   500; // ns

  // ----------------------------
  // DUT IO
  // ----------------------------
  reg         rst_n;
  reg         clk1, clk2;

  reg         valid_in;
  reg signed [15:0] din;

  reg         cload;
  reg  [5:0]  caddr;
  reg signed [15:0] cin;

  wire signed [15:0] dout;
  wire        valid_out;
  wire        done;

  // ----------------------------
  // Instantiate DUT
  // ----------------------------
  FIR_top dut (
    .rst_n     (rst_n),
    .clk1      (clk1),
    .clk2      (clk2),

    .valid_in  (valid_in),
    .din       (din),

    .cload     (cload),
    .caddr     (caddr),
    .cin       (cin),

    .dout      (dout),
    .valid_out (valid_out),
    .done      (done)
  );

  // ----------------------------
  // Clocks (start in phase at t=0)
  // ----------------------------
  initial begin
    clk1 = 1'b0;
    forever #(CLK1_HALF) clk1 = ~clk1;
  end

  initial begin
    clk2 = 1'b0;
    forever #(CLK2_HALF) clk2 = ~clk2;
  end

  // ----------------------------
  // Memories
  // ----------------------------
  reg signed [15:0] coef_mem [0:N_COEF-1];
  reg signed [15:0] data_mem [0:N_SAMP-1];

  // ----------------------------
  // File load tasks (binary per line, recommended 16-bit)
  // ----------------------------
  task load_coef_file;
    integer fd;
    integer i;
    integer r;
    reg [15:0] tmp16;
    begin
      fd = $fopen("CMEM.txt", "r");
      if (fd == 0) begin
        $display("ERROR: cannot open CMEM.txt");
        $finish;
      end

      for (i = 0; i < N_COEF; i = i + 1) begin
        r = $fscanf(fd, "%b\n", tmp16);
        if (r != 1) begin
          $display("ERROR: CMEM.txt parse failed at line %0d", i);
          $finish;
        end
        coef_mem[i] = tmp16; // keep bit pattern (Q1.15)
      end

      $fclose(fd);
      $display("Loaded %0d coefficients from CMEM.txt", N_COEF);
    end
  endtask

  task load_data_file;
    integer fd;
    integer i;
    integer r;
    reg [15:0] tmp16;
    begin
      fd = $fopen("DATA.txt", "r");
      if (fd == 0) begin
        $display("ERROR: cannot open DATA.txt");
        $finish;
      end

      for (i = 0; i < N_SAMP; i = i + 1) begin
        r = $fscanf(fd, "%b\n", tmp16);
        if (r != 1) begin
          $display("ERROR: DATA.txt parse failed at line %0d", i);
          $finish;
        end
        data_mem[i] = tmp16; // keep bit pattern (Q1.15)
      end

      $fclose(fd);
      $display("Loaded %0d samples from DATA.txt", N_SAMP);
    end
  endtask

  // ----------------------------
  // Output capture
  // ----------------------------
  integer fout;
  integer out_count;

  initial begin
    fout = $fopen("fir_out.txt", "w");
    if (fout == 0) begin
      $display("ERROR: cannot open fir_out.txt for write");
      $finish;
    end
    out_count = 0;
  end

  always @(posedge clk2) begin
    if (valid_out) begin
      // write 16-bit binary (bit-accurate, good for MATLAB bin2dec + two's complement)
      $fwrite(fout, "%016b\n", dout);
      out_count = out_count + 1;
    end
  end

  // ----------------------------
  // Main stimulus
  // ----------------------------
  integer k;
  integer n;

  initial begin
    // waveform
    $dumpfile("tb_fir_top.vcd");
    $dumpvars(0, tb_FIR_top);

    // init
    rst_n    = 1'b0;
    valid_in = 1'b0;
    din      = 16'sd0;

    cload    = 1'b0;
    caddr    = 6'd0;
    cin      = 16'sd0;

    // load txt files
    load_coef_file();
    load_data_file();

    // reset for a few clk2 cycles
    repeat(5) @(posedge clk2);
    rst_n = 1'b1;

    // ------------------------------------------------------------
    // 1) preload coefficients on clk2
    //    each clk2 cycle update caddr/cin stably
    // ------------------------------------------------------------
    @(posedge clk2);
    cload    <= 1'b1;
    valid_in <= 1'b0;  // keep low during preload

    for (k = 0; k < N_COEF; k = k + 1) begin
      @(posedge clk2);
      caddr <= k[5:0];
      cin   <= coef_mem[k];
    end

    @(posedge clk2);
    cload <= 1'b0;

    // ------------------------------------------------------------
    // 2) stream 10000 samples on clk1 (aligned with clk2)
    // ------------------------------------------------------------
    for (n = 0; n < N_SAMP+1; n = n + 1) begin
      @(posedge clk1);
      valid_in <= 1'b1;
      din      <= data_mem[n];
    end

    @(posedge clk1);
    valid_in <= 1'b0;
    din      <= 16'sd0;

    // drain some cycles
    repeat(5000) @(posedge clk2);

    $display("TB finished. Captured outputs: %0d lines (fir_out.txt).", out_count);
    $fclose(fout);
    $finish;
  end

endmodule

