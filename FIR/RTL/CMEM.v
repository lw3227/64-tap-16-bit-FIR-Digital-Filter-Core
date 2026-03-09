
module CMEM (
    input  wire        clk,
    input  wire        rst_n,   
    input  wire        we,
    input  wire        re,
    input  wire [5:0]  addr,
    input  wire [15:0] din,
    output wire [15:0] dout
);

    reg [15:0] mem [0:63];
    integer i;

   assign dout = re?mem[addr]:16'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 64; i = i + 1) begin
                mem[i] <= 16'd0;
            end
        end else begin
            if (we)
                mem[addr] <= din;
        end
    end

endmodule

