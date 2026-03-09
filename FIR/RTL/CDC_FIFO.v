
module CDC_FIFO(
  input        rst_n,
  input        clk1,
  input        we,
  input [15:0] din,

  input        clk2,
  input        re,

  output reg [15:0] dout,
  output            full,
  output            empty
);

  // depth = 16
  reg [15:0] data [15:0];

  // binary & gray pointers (5 bits: [4] is wrap bit, [3:0] is address)
  reg [4:0] w_ptr, w_ptr_gray;
  reg [4:0] r_ptr, r_ptr_gray;

  // synchronized pointers
  reg [4:0] w_ptr_1, w_ptr_2;  // wptr gray sync into clk2
  reg [4:0] r_ptr_1, r_ptr_2;  // rptr gray sync into clk1

  integer i;

  // ------------------------------------------------------------
  // Synchronizers
  // ------------------------------------------------------------

  // write pointer gray: clk1 -> clk2
  always @(posedge clk2 or negedge rst_n) begin
    if(!rst_n) begin
      w_ptr_1 <= 5'd0;
      w_ptr_2 <= 5'd0;
    end else begin
      w_ptr_1 <= w_ptr_gray;
      w_ptr_2 <= w_ptr_1;
    end
  end

  // read pointer gray: clk2 -> clk1
  always @(posedge clk1 or negedge rst_n) begin
    if(!rst_n) begin
      r_ptr_1 <= 5'd0;
      r_ptr_2 <= 5'd0;
    end else begin
      r_ptr_1 <= r_ptr_gray;
      r_ptr_2 <= r_ptr_1;
    end
  end

  // ------------------------------------------------------------
  // FULL generation (keep your original style)
  // full when next write pointer catches read pointer (in gray space with MSBs inverted)
  // NOTE: this is standard for async FIFO.
  // ------------------------------------------------------------
  assign full = (w_ptr_gray == {~r_ptr_2[4:3], r_ptr_2[2:0]});

  // ------------------------------------------------------------
  // WRITE side (clk1)
  // ------------------------------------------------------------
  always @(posedge clk1 or negedge rst_n) begin
    if(!rst_n) begin
      w_ptr      <= 5'd0;
      w_ptr_gray <= 5'd0;
    end else if (we && !full) begin
      w_ptr      <= w_ptr + 5'd1;
      w_ptr_gray <= (( (w_ptr + 5'd1) >> 1) ^ (w_ptr + 5'd1));
    end
  end

  always @(posedge clk1 or negedge rst_n) begin
    if(!rst_n) begin
      for (i = 0; i < 16; i = i + 1)
        data[i] <= 16'd0;
    end else if (we && !full) begin
      data[w_ptr[3:0]] <= din;
    end
  end

  // ------------------------------------------------------------
  // READ side (clk2) + EMPTY generation (FIXED)
  // Use NEXT read pointer to predict empty, avoiding extra read at wrap.
  // ------------------------------------------------------------

  reg empty_r;
  assign empty = empty_r;

  wire do_read = re && !empty_r;

  wire [4:0] r_ptr_next      = r_ptr + (do_read ? 5'd1 : 5'd0);
  wire [4:0] r_ptr_gray_next = (r_ptr_next >> 1) ^ r_ptr_next;

  wire empty_next = (r_ptr_gray_next == w_ptr_2);

  always @(posedge clk2 or negedge rst_n) begin
    if(!rst_n) begin
      r_ptr      <= 5'd0;
      r_ptr_gray <= 5'd0;
      empty_r    <= 1'b1;
    end else begin
      if (do_read) begin
        r_ptr      <= r_ptr_next;
        r_ptr_gray <= r_ptr_gray_next;
      end
      // update empty every cycle (tracks w_ptr_2 movement too)
      empty_r <= empty_next;
    end
  end

  // registered dout (read current address before pointer advances)
  always @(posedge clk2 or negedge rst_n) begin
    if(!rst_n) begin
      dout <= 16'd0;
    end else if (do_read) begin
      dout <= data[r_ptr[3:0]];
    end
  end

endmodule

