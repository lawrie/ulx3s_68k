module gamerom (
  input             clk,
  input [14:1]      addr,
  output reg [15:0] dout,
  input             we_b,
  input [14:1]      addr_b,
  input [15:0]      din_b
);

  parameter MEM_INIT_FILE = "";
   
  reg [15:0] rom [0:16383];

  initial
    if (MEM_INIT_FILE != "")
      $readmemh(MEM_INIT_FILE, rom);
   
  always @(posedge clk) begin
    dout <= rom[addr];
  end

  always @(posedge clk) begin
    if (we_b)
      rom[addr_b] <= din_b;
  end

endmodule
