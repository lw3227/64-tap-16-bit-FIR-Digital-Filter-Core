`timescale 1ns / 1ps


module shift_reg(
  input clk,
  input rst_n,
  input [15:0]Din,
  input we,
  input se,
  input re,
  input [5:0]addr,
  output [15:0]Dout
  );
      
  reg [15:0]D[63:0];
  integer i;
  
  assign Dout= re?D[addr]:0;
  
  always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      for (i=0;i<64;i=i+1) 
      D[i]<=0;
      end
      
    else begin
      
     if (we)
      D[0]<=Din;   
     
     if (se) begin
       for (i=63; i>0; i=i-1)
         D[i] <= D[i-1];
     end
     
    end

        
    end
 
    
endmodule

