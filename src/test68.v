`default_nettype none
module test68
#(
  parameter c_slowdown    = 2, // CPU clock slowdown 2^n times (try 20-22)
  parameter c_lcd_hex     = 1, // SPI lcd HEX decoder
  parameter c_sdram       = 1, // 1:SDRAM, 0:BRAM 32K
  parameter c_vga_out     = 0, // 0: Just HDMI, 1: VGA and HDMI
  parameter c_diag        = 0  // 0: No led diagnostcs, 1: led diagnostics
)
(
  input         clk25_mhz,
  // Buttons
  input [6:0]   btn,
  // Switches
  input [3:0]   sw,
  // HDMI
  output [3:0]  gpdi_dp,
  // Keyboard
  output        usb_fpga_pu_dp,
  output        usb_fpga_pu_dn,
  inout         ps2Clk,
  inout         ps2Data,
  // Audio
  output [3:0]  audio_l,
  output [3:0]  audio_r,
  // ESP32 passthru
  input         ftdi_txd,
  output        ftdi_rxd,
  input         wifi_txd,
  output        wifi_rxd,  // SPI from ESP32
  input         wifi_gpio16,
  input         wifi_gpio5,
  output        wifi_gpio0,

  inout  sd_clk, sd_cmd,
  inout   [3:0] sd_d,
  output sdram_csn,       // chip select
  output sdram_clk,       // clock to SDRAM
  output sdram_cke,       // clock enable to SDRAM
  output sdram_rasn,      // SDRAM RAS
  output sdram_casn,      // SDRAM CAS
  output sdram_wen,       // SDRAM write-enable
  output [12:0] sdram_a,  // SDRAM address bus
  output  [1:0] sdram_ba, // SDRAM bank-address
  output  [1:0] sdram_dqm,// byte select
  inout  [15:0] sdram_d,  // data bus to/from SDRAM
  inout  [27:0] gp,gn,
  // SPI display
  output oled_csn,
  output oled_clk,
  output oled_mosi,
  output oled_dc,
  output oled_resn,
  // Leds
  output [7:0]  leds
);

  // ===============================================================
  // System Clock generation
  // ===============================================================
  wire clk_sdram_locked;
  wire [3:0] clocks;

  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz(125*1000000),
    .out1_hz( 25*1000000),
    .out2_hz(100*1000000),                // SDRAM core
    .out3_hz(100*1000000), .out3_deg(90)  // SDRAM chip 45-330:ok 0-30:not
  )
  ecp5pll_inst
  (
    .clk_i(clk25_mhz),
    .clk_o(clocks),
    .locked(clk_sdram_locked)
  );

  wire clk_hdmi  = clocks[0];
  wire clk_vga   = clocks[1];
  wire clk_cpu   = clocks[1];
  wire clk_sdram = clocks[2];
  wire sdram_clk = clocks[3];
  assign sdram_cke = 1'b1;

  // ===============================================================
  // Reset generation
  // ===============================================================
  reg [15:0] pwr_up_reset_counter = 0;
  wire       pwr_up_reset_n = &pwr_up_reset_counter;

  always @(posedge clk_cpu) begin
     if (clk_sdram_locked && !pwr_up_reset_n)
       pwr_up_reset_counter <= pwr_up_reset_counter + 1;
  end

  // ===============================================================
  // Ulx3s-specific pin assignments
  // ===============================================================

  // Pull-ups for us2 connector
  assign usb_fpga_pu_dp = 1;
  assign usb_fpga_pu_dn = 1;

  // Passthru to ESP32 micropython serial console
  assign wifi_rxd = ftdi_txd;
  assign ftdi_rxd = wifi_txd;

  // ===============================================================
  // Optional VGA output
  // ===============================================================
  wire   [7:0]  red;
  wire   [7:0]  green;
  wire   [7:0]  blue;
  wire          hSync;
  wire          vSync;

  // Pinout for Digilent VGA Pmod. Change for other pmods.
  generate
    genvar i;
    if (c_vga_out) begin
      for(i = 0; i < 4; i = i+1) begin
        assign gn[10-i] = red[4+i];
        assign gn[3-i] = green[4+i];
        assign gp[10-i] = blue[4+i];
      end
      assign gp[2] = vSync;
      assign gp[3] = hSync;
    end
  endgenerate

  // ===============================================================
  // Diagnostic leds
  // ===============================================================
  reg [15:0] diag16;

  generate
    genvar i;
    if (c_diag) begin
      for(i = 0; i < 4; i = i+1) begin
        assign gn[17-i] = diag16[8+i];
        assign gp[17-i] = diag16[12+i];
        assign gn[24-i] = diag16[i];
        assign gp[24-i] = diag16[4+i];
      end
    end
  endgenerate

  // ===============================================================
  // 68000 CPU
  // ===============================================================
  reg  fx68_phi1;                // Phi 1 enable
  reg  fx68_phi2;                // Phi 2 enable (for slow cpu)
  wire cpu_rw;                   // Read = 1, Write = 0
  wire cpu_as_n;                 // Address strobe
  wire cpu_lds_n;                // Lower byte
  wire cpu_uds_n;                // Upper byte
  wire cpu_E;                    // Peripheral enable
  wire vma_n;                    // Valid memory address
  reg  vpa_n = 1'b0;             // Valid peripheral address
  wire cpu_fc0;                  // Processor state
  wire cpu_fc1;
  wire cpu_fc2;
  reg  berr_n = 1'b1;            // Bus error.
  wire cpu_reset_n_o;            // Reset output signal
  reg  dtack_n = 1'b0;           // Data transfer ack (always ready)
  wire bg_n;                     // Bus grant
  reg  bgack_n = 1'b1;           // Bus grant ack
  reg  ipl0_n = 1'b1;            // Interrupt request signals
  reg  ipl1_n = 1'b1;
  reg  ipl2_n = 1'b1;
  wire [15:0] ram_dout;
  wire [15:0] rom_dout;
  wire [7:0]  vga_dout;
  wire [15:0] cpu_din;           // Data to CPU
  wire [15:0] cpu_dout;          // Data from CPU
  wire [23:1] cpu_a;             // Address
  reg  halt_n = 1'b1;            // Halt request
  reg [7:0] R_cpu_control = 0;   // SPI loader

  assign cpu_din = cpu_a[17:15] < 2  ? rom_dout :
                   cpu_a[17:15] == 2 ? vga_dout :
		                       ram_dout;

  generate
    if(c_slowdown)
    begin
      // Run 68k CPU SLOW
      reg [c_slowdown-1:0] delay_cnt;
      always @(posedge clk_cpu)
      begin
        fx68_phi1 <= delay_cnt == 0;
        fx68_phi2 <= delay_cnt == {1'b1,{(c_slowdown-1){1'b0}}};
        delay_cnt <= delay_cnt + 1;
      end
    end
    else // c_slowdown == 0, Run 68k CPU at 12.5 MHz
      always @(posedge clk_cpu)
      begin
        fx68_phi1 <= ~fx68_phi1;
        fx68_phi2 <=  fx68_phi1;
      end
  endgenerate

  fx68k fx68k (
    // input
    .clk( clk_cpu),
    .HALTn(halt_n),
    .extReset(!btn[0] || !pwr_up_reset_n || R_cpu_control[0]),
    .pwrUp(!pwr_up_reset_n),
    .enPhi1(fx68_phi1),
    .enPhi2(fx68_phi2),
    // output
    .eRWn(cpu_rw),
    .ASn(cpu_as_n),
    .LDSn(cpu_lds_n),
    .UDSn(cpu_uds_n),
    .E(cpu_E),
    .VMAn(vma_n),
    .FC0(cpu_fc0),
    .FC1(cpu_fc1),
    .FC2(cpu_fc2),
    .BGn(bg_n),
    .oRESETn(cpu_reset_n_o),
    .oHALTEDn(),
    // input
    .DTACKn(dtack_n),
    .VPAn(vpa_n),
    .BERRn(berr_n),
    .BRn(1'b1),       // No bus requests
    .BGACKn(1'b1),
    .IPL0n(ipl0_n),
    .IPL1n(ipl1_n),
    .IPL2n(ipl2_n),
    .iEdb(cpu_din),
    // output
    .oEdb(cpu_dout),
    .eab(cpu_a)
  );

  // ===============================================================
  // Joystick for OSD control and games
  // ===============================================================
  reg [6:0] R_btn_joy;
  always @(posedge clk_cpu)
    R_btn_joy <= btn;

  // ===============================================================
  // SPI Slave for RAM and CPU control
  // ===============================================================
  wire [15:0] ram_do; // from SDRAM chip
  wire        spi_ram_wr, spi_ram_rd;
  wire [31:0] spi_ram_addr;
  wire  [7:0] spi_ram_di = spi_ram_addr[0] ? ram_do[7:0] : ram_do[15:8];
  wire  [7:0] spi_ram_do;

  assign sd_d[0] = 1'bz;
  assign sd_d[3] = 1'bz; // FPGA pin pullup sets SD card inactive at SPI bus

  wire irq;

  spi_ram_btn
  #(
    .c_sclk_capable_pin(1'b0),
    .c_addr_bits(32)
  )
  spi_ram_btn_inst
  (
    .clk(clk_cpu),
    .csn(~wifi_gpio5),
    .sclk(wifi_gpio16),
    .mosi(sd_d[1]), // wifi_gpio4
    .miso(sd_d[2]), // wifi_gpio12
    .btn(R_btn_joy),
    .irq(irq),
    .wr(spi_ram_wr),
    .rd(spi_ram_rd),
    .addr(spi_ram_addr),
    .data_in(spi_ram_di),
    .data_out(spi_ram_do)
  );

  // Used for interrupt to ESP32
  assign wifi_gpio0 = ~irq;

  reg [7:0] R_spi_ram_byte[0:1];
  reg R_spi_ram_wr;
  reg spi_ram_word_wr;
  always @(posedge clk_cpu)
  begin
    R_spi_ram_wr <= spi_ram_wr;
    if(spi_ram_wr == 1'b1)
    begin
      if(spi_ram_addr[31:24] == 8'hFF)
	R_cpu_control <= spi_ram_do;
      else
	R_spi_ram_byte[spi_ram_addr[0]] <= spi_ram_do;
      if(R_spi_ram_wr == 1'b0)
      begin
        if(spi_ram_addr[31:24] == 8'h00 && spi_ram_addr[0] == 1'b1)
          spi_ram_word_wr <= 1'b1;
      end
    end
    else
      spi_ram_word_wr <= 1'b0;
  end
  wire [15:0] ram_di = { R_spi_ram_byte[0], R_spi_ram_byte[1] }; // to SDRAM chip

  // ===============================================================
  // SDRAM or BRAM for rom
  // ===============================================================
  generate
  if(c_sdram) begin

  wire we = spi_ram_word_wr;
  wire re = spi_ram_addr[31:24] == 8'h00 ? spi_ram_rd : 1'b0;
  assign rom_dout = ram_do;
  sdram_pnru_68k
  sdram_i
  (
    // cpu side
    .clk100_mhz(clk_sdram),
    .din (ram_di),
    .dout(ram_do),
    .addr(R_cpu_control[1] ? {1'b0, spi_ram_addr[23:1]} : {1'b0, cpu_a[23:1]}),
    .udsn(R_cpu_control[1] ? ~(we|re) : cpu_uds_n),
    .ldsn(R_cpu_control[1] ? ~(we|re) : cpu_lds_n),
    .asn (R_cpu_control[1] ? ~(we|re) : cpu_as_n),
    .rw  (R_cpu_control[1] ? ~we      : 1'b1),
    .rst (~clk_sdram_locked),

    // sdram side
    .sd_data(sdram_d),
    .sd_addr(sdram_a),
    .sd_dqm (sdram_dqm),
    .sd_ba  (sdram_ba),
    .sd_cs  (sdram_csn),
    .sd_we  (sdram_wen),
    .sd_ras (sdram_rasn),
    .sd_cas (sdram_casn)
  );

/*
  // Tristate sdram_d pins when reading
  wire sdram_d_wr; // SDRAM controller sets this when writing
  wire [15:0] sdram_d_in, sdram_d_out;
  assign sdram_d = sdram_d_wr ? sdram_d_out : 16'hzzzz;
  assign sdram_d_in = sdram_d;

  sdram
  sdram_i
  (
    .sd_data_in(sdram_d_in),
    .sd_data_out(sdram_d_out),
    .sd_data_wr(sdram_d_wr),
    .sd_addr(sdram_a),
    .sd_dqm(sdram_dqm),
    .sd_cs(sdram_csn),
    .sd_ba(sdram_ba),
    .sd_we(sdram_wen),
    .sd_ras(sdram_rasn),
    .sd_cas(sdram_casn),
    // system interface
    .clk_96(clk_sdram),
    .clk_8_en(fx68_phi1),
    .init(!clk_sdram_locked),
    // SPI interface
    .we(R_cpu_control[1] ? (spi_ram_word_wr & fx68_phi1) : 1'b0),
    .addr(spi_ram_addr[23:1]),
    .din(spi_ram_word),
    .req(R_cpu_control[1] ? ((spi_ram_word_wr | (spi_ram_rd == 1'b1 && spi_ram_addr[31:24] == 8'h00)) & fx68_phi1) : (cpu_rw & fx68_phi1)),
    .ds(2'b11),
    .dout(spi_ram_do),
    // ROM access port
    .rom_oe(R_cpu_control[1] ? 1'b0 : (cpu_rw & fx68_phi1)),
    .rom_addr(cpu_a),
    .rom_dout(rom_dout)
  );
*/
  end
  else
  gamerom #(.MEM_INIT_FILE("../roms/test.mem")) 
  rom16 (
    .clk(clk_cpu),
    .we_b(spi_ram_word_wr), // used by OSD
    .addr_b(spi_ram_addr[15:1]),
    .din_b(ram_di),
    .addr(cpu_a[15:1]),
    .dout(rom_dout)
  );
  endgenerate

  // ===============================================================
  // Ram
  // ===============================================================
  ram ram32 (
    .clk(clk_cpu),
    .addr(cpu_a[14:1]),
    .din(cpu_dout),
    .we(!cpu_rw && cpu_a[17:15] > 2),
    .dout(ram_dout),
    .ub(!cpu_uds_n),
    .lb(!cpu_lds_n)
  );


  // ===============================================================
  // Keyboard (not yet implemented)
  // ===============================================================
  wire [10:0] ps2_key;

  // Get PS/2 keyboard events
  ps2 ps2_kbd (
     .clk(clk_cpu),
     .ps2_clk(ps2Clk),
     .ps2_data(ps2Data),
     .ps2_key(ps2_key)
  );

  // ===============================================================
  // Video
  // ===============================================================
  wire [14:0] vid_addr; // Used by vdp
  wire [7:0]  vid_dout; // Used by vdp
  wire [14:0] vga_addr = cpu_a[14:1];
  wire        vga_wr = !cpu_rw && cpu_a[17:15] == 2;
  wire        vga_rd = cpu_rw && cpu_a[17:15] == 2;
  wire        vga_de;

  vram video_ram (
    .clk_a(clk_cpu),
    .addr_a(vga_addr),
    .we_a(vga_wr),
    .re_a(vga_rd),
    .din_a(cpu_dout),
    .ub_a(!cpu_uds_n),
    .lb_a(!cpu_lds_n),
    .dout_a(vga_dout),
    .clk_b(clk_vga),
    .addr_b(vid_addr),
    .dout_b(vid_dout)
  );

  video vga (
    .clk(clk_vga),
    .vga_r(red),
    .vga_g(green),
    .vga_b(blue),
    .vga_de(vga_de),
    .vga_hs(hSync),
    .vga_vs(vSync),
    .vid_addr(vid_addr),
    .vid_dout(vid_dout)
  );

  // ===============================================================
  // SPI Slave for OSD display
  // ===============================================================
  wire [7:0] osd_vga_r, osd_vga_g, osd_vga_b;
  wire osd_vga_hsync, osd_vga_vsync, osd_vga_blank;
  spi_osd
  #(
    .c_start_x(62), .c_start_y(80),
    .c_chars_x(64), .c_chars_y(20),
    .c_init_on(0),
    .c_transparency(1),
    .c_char_file("osd.mem"),
    .c_font_file("font_bizcat8x16.mem")
  )
  spi_osd_inst
  (
    .clk_pixel(clk_vga), .clk_pixel_ena(1),
    .i_r(red  ),
    .i_g(green),
    .i_b(blue ),
    .i_hsync(~hSync), .i_vsync(~vSync), .i_blank(~vga_de),
    .i_csn(~wifi_gpio5), .i_sclk(wifi_gpio16), .i_mosi(sd_d[1]), // .o_miso(),
    .o_r(osd_vga_r), .o_g(osd_vga_g), .o_b(osd_vga_b),
    .o_hsync(osd_vga_hsync), .o_vsync(osd_vga_vsync), .o_blank(osd_vga_blank)
  );

  // ===============================================================
  // Convert VGA to HDMI
  // ===============================================================
  HDMI_out vga2dvid (
    .pixclk(clk_vga),
    .pixclk_x5(clk_hdmi),
    .red  (osd_vga_r),
    .green(osd_vga_g),
    .blue (osd_vga_b),
    .vde  (~osd_vga_blank),
    .hSync(~osd_vga_hsync),
    .vSync(~osd_vga_vsync),
    .gpdi_dp(gpdi_dp),
    .gpdi_dn()
  );

  // ===============================================================
  // Audio (not yet implemented)
  // ===============================================================
  assign audio_l = 0;
  assign audio_r = audio_l;

  // ===============================================================
  // Diagnostic leds
  // ===============================================================
  //assign leds = {cpu_fc2, cpu_fc1, cpu_fc0};
  assign leds = cpu_dout;

  //always @(posedge clk_cpu) diag16 = cpu_a[16:1];
  //always @(posedge clk_cpu) diag16 = cpu_a[16:1];

  generate
  if(c_lcd_hex)
  begin
  // SPI DISPLAY
  reg [127:0] R_display;
  // HEX decoder does printf("%16X\n%16X\n", R_display[63:0], R_display[127:64]);
  always @(posedge clk_cpu)
    R_display <= { 1'b0, R_btn_joy, cpu_dout, cpu_din, cpu_a, 1'b0 };

  parameter C_color_bits = 16;
  wire [7:0] x;
  wire [7:0] y;
  wire [C_color_bits-1:0] color;
  hex_decoder_v
  #(
    .c_data_len(128),
    .c_row_bits(4),
    .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
    .c_font_file("hex_font.mem"),
    .c_color_bits(C_color_bits)
  )
  hex_decoder_v_inst
  (
    .clk(clk_hdmi),
    .data(R_display),
    .x(x[7:1]),
    .y(y[7:1]),
    .color(color)
  );

  // allow large combinatorial logic
  // to calculate color(x,y)
  wire next_pixel;
  reg [C_color_bits-1:0] R_color;
  always @(posedge clk_hdmi)
    if(next_pixel)
      R_color <= color;

  wire w_oled_csn;
  lcd_video
  #(
    .c_clk_mhz(125),
    .c_init_file("st7789_linit_xflip.mem"),
    .c_clk_phase(0),
    .c_clk_polarity(1),
    .c_init_size(38)
  )
  lcd_video_inst
  (
    .clk(clk_hdmi),
    .reset(R_btn_joy[5]),
    .x(x),
    .y(y),
    .next_pixel(next_pixel),
    .color(R_color),
    .spi_clk(oled_clk),
    .spi_mosi(oled_mosi),
    .spi_dc(oled_dc),
    .spi_resn(oled_resn),
    .spi_csn(w_oled_csn)
  );
  //assign oled_csn = w_oled_csn; // 8-pin ST7789: oled_csn is connected to CSn
  assign oled_csn = 1; // 7-pin ST7789: oled_csn is connected to BLK (backlight enable pin)
  end
  endgenerate

endmodule

