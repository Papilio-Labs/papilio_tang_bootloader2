// top.v
// Simple 1-second blink for pin L16 driven by a 27 MHz clock.
// Assumption: input clock is 27_000_000 Hz. The LED (net `L16`) is
// toggled every 27,000,000 clock cycles -> one toggle per second.
// That means a full on/off cycle is 2 seconds.

`timescale 1ns/1ps

module top (
    input  wire clk_27mhz, // 27 MHz input clock
    output wire led,        // top-level LED port; map this to physical pin L16 in constraints
    output wire reconfig,    // reconfiguration mode pin (active high)
    input  wire rst_n,        // Active low reset
    output wire rgb_led,     // WS2812B RGB LED data output

//    SPI Flash programming
    input wire          esp_clk,
    input wire          esp_cs_n,
    output  wire          esp_miso,
    input wire          esp_mosi,

    output  wire          spiflash_clk,
    output  wire          spiflash_cs_n,
    input wire          spiflash_miso,
    output  wire          spiflash_mosi
);

    // Instantiate the parameterized LED blink module. The clock frequency
    // is given in MHz (CLOCK_MHZ) and the interval is in seconds (SECONDS).
    // With CLOCK_MHZ=27 and SECONDS=1 the LED toggles once per second -> 1s ON / 1s OFF.
     led_blink #(
         .CLOCK_MHZ(27),
         .SECONDS(1)
     ) u_led_blink (
         .clk(clk_27mhz),
         .led(led)
     );

    // Timed reconfiguration control: hold high for 5 seconds, then low
    timed_restart #(
        .CLOCK_MHZ(27),
        .HOLD_SECS(2)
    ) u_timed_restart (
        .clk(clk_27mhz),
        .esp_cs_n(esp_cs_n),
        .reconfig(reconfig)
    );

    // SPI Flash
    assign spiflash_clk = esp_clk;
    assign spiflash_mosi = esp_mosi;
    assign spiflash_cs_n = esp_cs_n;
    assign esp_miso = spiflash_miso;



    // WS2812B RGB LED controller
    
    // Common colors (GRB format):
    // Red:     24'h00FF00
    // Green:   24'hFF0000
    // Blue:    24'h0000FF
    // Yellow:  24'hFFFF00
    // Cyan:    24'hFF00FF
    // Magenta: 24'h00FFFF
    // White:   24'hFFFFFF
    // Purple:  24'h007F7F
    // Orange:  24'h80FF00 (bright), 24'h081000 (dim)
    // Off:     24'h000000
    
    // Detect if CS pin has ever gone low (SPI activity detected)
    reg cs_detected;
    
    always @(posedge clk_27mhz or negedge rst_n) begin
        if (!rst_n) begin
            cs_detected <= 1'b0;
        end else if (esp_cs_n == 1'b0) begin
            cs_detected <= 1'b1;  // Latch on first CS activity
        end
    end
    
    // Select color: show cyan when CS is active (low) OR has been detected, purple otherwise
    // This makes it immediately responsive to CS activity
    wire [23:0] led_color;
    assign led_color = (esp_cs_n == 1'b0 || cs_detected) ? 24'h080008 : 24'h000505;  // Dim Cyan : Purple
    
    ws2812b u_ws2812b (
        .clk(clk_27mhz),
        .rst_n(rst_n),
        .led_color_in(led_color),
        .dout(rgb_led)
    );

endmodule
