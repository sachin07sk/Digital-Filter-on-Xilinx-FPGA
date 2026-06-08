// ============================================
// FIR Filter Top Module
// Top-level wrapper for FPGA implementation
// Adds I/O registers for timing closure
// Author: Saravana Kumar T J A
// ============================================
module fir_top (
    input  wire        clk,
    input  wire        rst,
    input  wire        valid_in,
    input  wire [15:0] data_in,
    output wire        valid_out,
    output wire [15:0] data_out
);

    // ── Input register (improves timing) ─────
    reg        valid_in_r;
    reg [15:0] data_in_r;

    always @(posedge clk) begin
        if (rst) begin
            valid_in_r <= 1'b0;
            data_in_r  <= 16'd0;
        end
        else begin
            valid_in_r <= valid_in;
            data_in_r  <= data_in;
        end
    end

    // ── FIR Filter Instance ───────────────────
    fir_filter u_fir (
        .clk       (clk),
        .rst       (rst),
        .valid_in  (valid_in_r),
        .data_in   (data_in_r),
        .valid_out (valid_out),
        .data_out  (data_out)
    );

endmodule
