
module FSM(
input clk, 
input rst_n,
input valid_in,
input cload, 
input FIFO_empty,
input FIFO_full,
input [6:0]CNT_64,

output reg FIFO_we,
output reg FIFO_re,
output reg MEM_re,
output reg MEM_we,
output reg shift_en,
output reg REG_re,
output reg REG_we,
output reg ACC_en,
output reg [13:0]CNT_10000,
output reg END
    );
    

reg [2:0]y, Y; 

    
//control circuit
parameter IDLE=3'b000, 
          PRE_LOAD=3'b001, 
          WAIT_DATA=3'b010,
          REG_WRITE=3'b011,
          MAC=3'b100,
          SHIFT=3'b101;

always@(*)
 begin
  case(y)
   IDLE: begin
    if(cload)Y = PRE_LOAD;
   else Y = IDLE;
    end
   PRE_LOAD: begin
    if(valid_in)//din_EN?
    Y=WAIT_DATA;
    else Y = PRE_LOAD;
   end
   WAIT_DATA: 
    if(valid_in & !FIFO_empty) Y = REG_WRITE;
    else Y = WAIT_DATA;
   REG_WRITE:
    Y= MAC;
   MAC: 
    if(CNT_64==63)//or64
     Y=SHIFT;
     else Y=MAC;
    
    SHIFT:
    if(CNT_10000==10001)
     Y=PRE_LOAD;
    else Y=WAIT_DATA;
    
   default  Y=IDLE;
   endcase 
 end
 
 always @(posedge clk or negedge rst_n)
  begin:State_flipflops
   if(rst_n==0)
    y<=IDLE;
   else y<=Y;
  end
  
 always @(*)
  begin:FSM_output
  //default
   FIFO_we=0; FIFO_re=0;
   MEM_we=0; MEM_re=0;
   shift_en=0;REG_re=0;REG_we=0;
   ACC_en=0;
   case(y)
    IDLE: begin
     end
     
    PRE_LOAD: //load coe到CMEM
     MEM_we=1;
     
    WAIT_DATA: begin
     FIFO_re=0;
     if(!FIFO_full)
      FIFO_we=1;
     end
    
    REG_WRITE:begin
     FIFO_re=1;
     REG_we=1;
     end
     
    MAC:begin
     FIFO_re=0;
     MEM_re=1;
     REG_re=1;
     REG_we=0;
     ACC_en=1;
     end
     
    SHIFT: begin
     ACC_en=0;
     REG_re=0;
     shift_en=1;
     end
     
     default ;
    endcase
    end
    
    //COUNTER
 always @(posedge clk or negedge rst_n) 
  begin
   if(!rst_n) begin
    CNT_10000<=0;
    END<=0;
   end
   else if (y==SHIFT) begin
    CNT_10000<=CNT_10000+1;
    if(CNT_10000==9999) begin
     CNT_10000<=0;
     END<=1;
     end
   end
   
  end

endmodule

