module ALU(
    input  wire signed [15:0] Din,
    input  wire signed [15:0] Cin,
    input  wire clk,
    input  wire EN_cal,
    input  wire rst_n,
    output reg  signed [15:0] Dout,
    output reg [6:0] CNT_mac    // 0 ~ 63
);

    //reg signed [15:0] coe;
    //reg signed [15:0] xin;

    reg signed [36:0] acc;
    wire signed [31:0] mul;

   


    // multiplier (signed)
    assign mul = EN_cal ? $signed(Din) * $signed(Cin) : 32'sd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            CNT_mac  <= 0;
            acc      <= 0;
            Dout     <= 0;
            //xin      <= 0;
           // coe      <= 0;
        end

        // ---------- load inputs ----------
        else begin
            //xin <= Din;
            //coe <= Cin;
            // ---------- MAC ----------
            if (EN_cal) begin
                acc <= acc + mul;
                CNT_mac <= CNT_mac + 1; 
                    Dout <= acc[36:21];  // truncate

                if (CNT_mac == 64) begin
                    acc <= 0;
                    CNT_mac <= 0;
                end
            end
        end
    end

endmodule


