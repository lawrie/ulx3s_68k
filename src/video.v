`default_nettype none
module video (
  input         clk,
  input         reset,
  output [7:0]  vga_r,
  output [7:0]  vga_b,
  output [7:0]  vga_g,
  output        vga_hs,
  output        vga_vs,
  output        vga_de,
  input  [7:0]  vid_dout,
  output reg [14:0] vid_addr
);

  parameter HA = 640;
  parameter HS  = 96;
  parameter HFP = 16;
  parameter HBP = 48;
  parameter HT  = HA + HS + HFP + HBP;

  parameter VA = 480;
  parameter VS  = 2;
  parameter VFP = 11;
  parameter VBP = 31;
  parameter VT  = VA + VS + VFP + VBP;
  parameter HBadj = 2;

  reg [7:0]  vb  = 112;
  reg [7:0]  hb  = 64;
  wire [7:0] hb2 = hb[6:1];

  // Default palette
  localparam transparent  = 24'h000000;
  localparam black        = 24'h010101;
  localparam medium_green = 24'h3eb849;
  localparam light_green  = 24'h74d07d;
  localparam dark_blue    = 24'h5955e0;
  localparam light_blue   = 24'h8076f1;
  localparam dark_red     = 24'h993e31;
  localparam cyan         = 24'h65dbef;
  localparam medium_red   = 24'hdb6559;
  localparam light_red    = 24'hff897d;
  localparam dark_yellow  = 24'hccc35e;
  localparam light_yellow = 24'hded087;
  localparam dark_green   = 24'h3aa241;
  localparam magenta      = 24'hb766b5;
  localparam gray         = 24'h777777;
  localparam white        = 24'hffffff;

  reg [23:0] colors [0:15];

  initial begin
    colors[0]  <= transparent;
    colors[1]  <= black;
    colors[2]  <= medium_green;
    colors[3]  <= light_green;
    colors[4]  <= dark_blue;
    colors[5]  <= light_blue;
    colors[6]  <= dark_red;
    colors[7]  <= cyan;
    colors[8]  <= medium_red;
    colors[9]  <= light_red;
    colors[10] <= dark_yellow;
    colors[11] <= light_yellow;
    colors[12] <= dark_green;
    colors[13] <= magenta;
    colors[14] <= gray;
    colors[15] <= white;
  end

  reg [9:0] hc = 0;
  reg [9:0] vc = 0;

  always @(posedge clk) begin
    if (reset) begin
      hc <= 0;
      vc <= 0;
    end else begin
      if (hc == HT - 1) begin
        hc <= 0;
        if (vc == VT - 1) vc <= 0;
        else vc <= vc + 1;
      end else hc <= hc + 1;
    end
  end

  assign vga_hs = !(hc >= HA + HFP && hc < HA + HFP + HS);
  assign vga_vs = !(vc >= VA + VFP && vc < VA + VFP + VS);
  assign vga_de = !(hc > HA || vc > VA);

  wire [7:0] x = hc[9:1] - hb2;
  wire [7:0] y = vc - vb;

  wire [7:0] x1 = x + 1;

  wire hBorder = (hc < (hb + HBadj) || hc >= HA - (hb + HBadj));
  wire vBorder = (vc < vb || vc >= VA - vb);
  wire border = hBorder || vBorder;

  // Read 2 pixels at a time
  reg [7:0] pixels;
  wire [3:0] pixel = x[0] ? pixels[7:4] : pixels[3:0];

  always @(posedge clk) begin
    if (hc[0] && hc < HA) begin
      if (x[0]) vid_addr <=  {y, x1[7:1]};
      else pixels <= vid_dout;
    end
  end

  wire [7:0] green = border ? 8'b0 : pixel[2] ? 8'hff : 8'b0;
  wire [7:0] red   = border ? 8'b0 : pixel[1] ? 8'hff : 8'b0;
  wire [7:0] blue  = border ? 8'b0 : pixel[0] ? 8'hff : 8'b0;

  assign vga_r = !vga_de ? 8'b0 : red;
  assign vga_g = !vga_de ? 8'b0 : green;
  assign vga_b = !vga_de ? 8'b0 : blue;

endmodule

