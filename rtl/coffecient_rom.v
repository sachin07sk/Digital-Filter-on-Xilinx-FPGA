// ============================================
// Coefficient ROM
// Stores 8 FIR filter coefficients
// Low-pass filter — 16-bit signed fixed-point
// Coefficients designed for Fc = 0.1 * Fs
// (cuts off at 10% of sample rate)
//
// Coefficient values (Q15 format — scaled by 32768):
//   h[0]=h[7]= 328  (symmetric FIR)
//   h[1]=h[6]= 1023
//   h[2]=h[5]= 2531
//   h[3]=h[4]= 4915
//
// Author: Saravana Kumar T J A
// ============================================
module coefficient_rom (
    input  wire [2:0]  addr,    // Coefficient index 0 to 7
    output reg  [15:0] coeff    // 16-bit signed coefficient
);

    always @(*) begin
        case (addr)
            3'd0: coeff = 16'sd328;
            3'd1: coeff = 16'sd1023;
            3'd2: coeff = 16'sd2531;
            3'd3: coeff = 16'sd4915;
            3'd4: coeff = 16'sd4915;
            3'd5: coeff = 16'sd2531;
            3'd6: coeff = 16'sd1023;
            3'd7: coeff = 16'sd328;
            default: coeff = 16'sd0;
        endcase
    end

endmodule
