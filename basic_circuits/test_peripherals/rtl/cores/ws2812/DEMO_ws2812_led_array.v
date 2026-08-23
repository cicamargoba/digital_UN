module DEMO_ws2812_led_array (
    input    reset,
    input    clk,
    output   dout
);

  ws2812_led_array u_ws2812_led_array(
      .reset   (!reset),
      .clk     (clk),
      .init_m  (1),
      .rst_cmd (0),
      .dout    (dout),
      .done    ()
  );

endmodule
