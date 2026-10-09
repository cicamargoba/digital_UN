module init_mem (
    input      [7:0] addr,
    output reg [9:0] data
);
localparam NUM_ENTRIES = 68;
always @(*) begin
    case (addr)
        8'd0  : data = {1'b0, 1'b0, 8'hE0};
        8'd1  : data = {1'b0, 1'b1, 8'h00};
        8'd2  : data = {1'b0, 1'b1, 8'h03};
        8'd3  : data = {1'b0, 1'b1, 8'h09};
        8'd4  : data = {1'b0, 1'b1, 8'h08};
        8'd5  : data = {1'b0, 1'b1, 8'h16};
        8'd6  : data = {1'b0, 1'b1, 8'h0A};
        8'd7  : data = {1'b0, 1'b1, 8'h3F};
        8'd8  : data = {1'b0, 1'b1, 8'h78};
        8'd9  : data = {1'b0, 1'b1, 8'h4C};
        8'd10 : data = {1'b0, 1'b1, 8'h09};
        8'd11 : data = {1'b0, 1'b1, 8'h0A};
        8'd12 : data = {1'b0, 1'b1, 8'h08};
        8'd13 : data = {1'b0, 1'b1, 8'h16};
        8'd14 : data = {1'b0, 1'b1, 8'h1A};
        8'd15 : data = {1'b0, 1'b1, 8'h0F};
        8'd16 : data = {1'b0, 1'b0, 8'hE1};
        8'd17 : data = {1'b0, 1'b1, 8'h00};
        8'd18 : data = {1'b0, 1'b1, 8'h16};
        8'd19 : data = {1'b0, 1'b1, 8'h19};
        8'd20 : data = {1'b0, 1'b1, 8'h03};
        8'd21 : data = {1'b0, 1'b1, 8'h0F};
        8'd22 : data = {1'b0, 1'b1, 8'h05};
        8'd23 : data = {1'b0, 1'b1, 8'h32};
        8'd24 : data = {1'b0, 1'b1, 8'h45};
        8'd25 : data = {1'b0, 1'b1, 8'h46};
        8'd26 : data = {1'b0, 1'b1, 8'h04};
        8'd27 : data = {1'b0, 1'b1, 8'h0E};
        8'd28 : data = {1'b0, 1'b1, 8'h0D};
        8'd29 : data = {1'b0, 1'b1, 8'h35};
        8'd30 : data = {1'b0, 1'b1, 8'h37};
        8'd31 : data = {1'b0, 1'b1, 8'h0F};
        8'd32 : data = {1'b0, 1'b0, 8'hC0};
        8'd33 : data = {1'b0, 1'b1, 8'h17};
        8'd34 : data = {1'b0, 1'b1, 8'h15};
        8'd35 : data = {1'b0, 1'b0, 8'hC1};
        8'd36 : data = {1'b0, 1'b1, 8'h41};
        8'd37 : data = {1'b0, 1'b0, 8'hC5};
        8'd38 : data = {1'b0, 1'b1, 8'h00};
        8'd39 : data = {1'b0, 1'b1, 8'h12};
        8'd40 : data = {1'b0, 1'b1, 8'h80};
        8'd41 : data = {1'b0, 1'b0, 8'h36};
        8'd42 : data = {1'b0, 1'b1, 8'h48};
        8'd43 : data = {1'b0, 1'b0, 8'h3A};
        8'd44 : data = {1'b0, 1'b1, 8'h66};
        8'd45 : data = {1'b0, 1'b0, 8'hB0};
        8'd46 : data = {1'b0, 1'b1, 8'h80};
        8'd47 : data = {1'b0, 1'b0, 8'hB1};
        8'd48 : data = {1'b0, 1'b1, 8'hA0};
        8'd49 : data = {1'b0, 1'b0, 8'hB4};
        8'd50 : data = {1'b0, 1'b1, 8'h02};
        8'd51 : data = {1'b0, 1'b0, 8'hB6};
        8'd52 : data = {1'b0, 1'b1, 8'h02};
        8'd53 : data = {1'b0, 1'b1, 8'h02};
        8'd54 : data = {1'b0, 1'b1, 8'h3B};
        8'd55 : data = {1'b0, 1'b0, 8'hB7};
        8'd56 : data = {1'b0, 1'b1, 8'hC6};
        8'd57 : data = {1'b0, 1'b0, 8'hE9};
        8'd58 : data = {1'b0, 1'b1, 8'h00};
        8'd59 : data = {1'b0, 1'b0, 8'hF7};
        8'd60 : data = {1'b0, 1'b1, 8'hA9};
        8'd61 : data = {1'b0, 1'b1, 8'h51};
        8'd62 : data = {1'b0, 1'b1, 8'h2C};
        8'd63 : data = {1'b0, 1'b1, 8'h82};
        8'd64 : data = {1'b0, 1'b0, 8'h11};
        8'd65 : data = {1'b1, 1'b0, 8'd120};
        8'd66 : data = {1'b0, 1'b0, 8'h29};
        8'd67 : data = {1'b1, 1'b0, 8'd100};
        default: data = 10'h000;
    endcase
end
endmodule
