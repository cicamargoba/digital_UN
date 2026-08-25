`timescale 1ns/1ps

module perip_blink_TB;

    reg         clk;
    reg         rst;
    reg  [31:0] d_in;
    reg         cs;
    reg  [3:0]  addr;
    reg         rd;
    reg         wr;
    wire [31:0] d_out;
    wire        led;

    integer errors;
    integer transitions;
    reg     previous_led;

    perip_blink dut (
        .clk(clk),
        .rst(rst),
        .d_in(d_in),
        .cs(cs),
        .addr(addr),
        .rd(rd),
        .wr(wr),
        .d_out(d_out),
        .led(led)
    );

    always #5 clk = ~clk;

    task csr_write;
        input [3:0]  write_addr;
        input [31:0] write_data;
        begin
            @(negedge clk);
            cs   = 1'b1;
            wr   = 1'b1;
            addr = write_addr;
            d_in = write_data;
            @(negedge clk);
            cs   = 1'b0;
            wr   = 1'b0;
        end
    endtask

    task csr_check;
        input [3:0]  read_addr;
        input [31:0] expected;
        begin
            @(negedge clk);
            cs   = 1'b1;
            rd   = 1'b1;
            addr = read_addr;
            #1;
            if (d_out !== expected) begin
                $display("ERROR: addr=%h expected=%h read=%h", read_addr, expected, d_out);
                errors = errors + 1;
            end
            @(negedge clk);
            cs = 1'b0;
            rd = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("perip_blink_TB.vcd");
        $dumpvars(0, perip_blink_TB);

        clk          = 1'b0;
        rst          = 1'b1;
        d_in         = 32'd0;
        cs           = 1'b0;
        addr         = 4'd0;
        rd           = 1'b0;
        wr           = 1'b0;
        errors       = 0;
        transitions  = 0;
        previous_led = 1'b0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        csr_write(4'h4, 32'd3);
        csr_write(4'h0, 32'd1);
        csr_check(4'h4, 32'd3);
        csr_check(4'h0, 32'd1);

        repeat (18) begin
            @(posedge clk);
            #1;
            if (led !== previous_led) begin
                transitions  = transitions + 1;
                previous_led = led;
            end
        end

        if (transitions < 4) begin
            $display("ERROR: only %0d LED transitions detected", transitions);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: blink CSR and LED behavior verified");
        else
            $display("FAIL: %0d errors", errors);

        $finish;
    end

endmodule
