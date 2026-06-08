// ============================================
// FIR Filter — Direct Form Implementation
// 8-tap low-pass filter
// 16-bit signed input and output
// Uses shift register + multiply-accumulate
//
// Algorithm:
//   y[n] = h[0]*x[n] + h[1]*x[n-1] + ...
//          + h[7]*x[n-7]
//
// Each sample:
//   1. Shift all previous samples right
//   2. Insert new sample at x[0]
//   3. Multiply each x[i] by h[i]
//   4. Sum all products = filtered output
//
// Author: Saravana Kumar T J A
// ============================================
module fir_filter (
    input  wire        clk,
    input  wire        rst,
    input  wire        valid_in,   // 1 = new sample available
    input  wire [15:0] data_in,    // 16-bit signed input sample
    output reg         valid_out,  // 1 = output sample ready
    output reg  [15:0] data_out    // 16-bit signed filtered output
);

    // Parameters
    parameter N_TAPS = 8;          // Number of filter taps
    parameter DATA_W = 16;         // Input data width
    parameter COEFF_W = 16;        // Coefficient width
    parameter ACC_W  = 40;         // Accumulator width (prevents overflow)
                                   // ACC_W = DATA_W + COEFF_W + log2(N_TAPS)
                                   //       = 16 + 16 + 3 = 35, use 40 for safety

    // ── Shift Register — stores last 8 samples ──
    // x_reg[0] = newest sample
    // x_reg[7] = oldest sample
    reg signed [DATA_W-1:0] x_reg [0:N_TAPS-1];

    // ── Coefficients from ROM ────────────────────
    wire signed [COEFF_W-1:0] coeff [0:N_TAPS-1];

    // Instantiate 8 coefficient ROM reads
    // (combinational — one ROM with 8 address lookups)
    coefficient_rom rom0 (.addr(3'd0), .coeff(coeff[0]));
    coefficient_rom rom1 (.addr(3'd1), .coeff(coeff[1]));
    coefficient_rom rom2 (.addr(3'd2), .coeff(coeff[2]));
    coefficient_rom rom3 (.addr(3'd3), .coeff(coeff[3]));
    coefficient_rom rom4 (.addr(3'd4), .coeff(coeff[4]));
    coefficient_rom rom5 (.addr(3'd5), .coeff(coeff[5]));
    coefficient_rom rom6 (.addr(3'd6), .coeff(coeff[6]));
    coefficient_rom rom7 (.addr(3'd7), .coeff(coeff[7]));

    // ── Multiply-Accumulate ──────────────────────
    // products[i] = x_reg[i] * coeff[i]
    wire signed [ACC_W-1:0] products [0:N_TAPS-1];

    genvar k;
    generate
        for (k = 0; k < N_TAPS; k = k + 1) begin : MULT
            assign products[k] = x_reg[k] * coeff[k];
        end
    endgenerate

    // ── Accumulator ──────────────────────────────
    reg signed [ACC_W-1:0] acc;

    integer m;
    always @(*) begin
        acc = 0;
        for (m = 0; m < N_TAPS; m = m + 1)
            acc = acc + products[m];
    end

    // ── Pipeline: shift register + output ────────
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            // Clear shift register
            for (i = 0; i < N_TAPS; i = i + 1)
                x_reg[i] <= {DATA_W{1'b0}};
            data_out  <= {DATA_W{1'b0}};
            valid_out <= 1'b0;
        end
        else begin
            valid_out <= 1'b0;

            if (valid_in) begin
                // Shift old samples right
                for (i = N_TAPS-1; i > 0; i = i - 1)
                    x_reg[i] <= x_reg[i-1];

                // Insert new sample at position 0
                x_reg[0] <= $signed(data_in);

                // Truncate accumulator to 16-bit output
                // Divide by 32768 (right shift 15) because
                // coefficients are in Q15 fixed-point format
                data_out  <= acc[DATA_W+14:15];
                valid_out <= 1'b1;
            end
        end
    end

endmodule
