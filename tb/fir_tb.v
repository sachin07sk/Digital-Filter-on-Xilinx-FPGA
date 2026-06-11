// ============================================
// FIR Filter Testbench
// Tests:
//   Test 1: Impulse response
//           Input: 1 sample = max value, rest = 0
//           Expected output: the filter coefficients
//
//   Test 2: DC response
//           Input: constant value = 1000
//           Expected output: ~1000 (low pass passes DC)
//
//   Test 3: High frequency rejection
//           Input: alternating +1000, -1000 (Nyquist freq)
//           Expected output: ~0 (low pass blocks high freq)
//
//   Test 4: Step response
//           Input: 0 then suddenly 1000
//           Expected: gradual rise to 1000
//
// Author: Saravana Kumar T J A
// ============================================
`timescale 1ns/1ps

module fir_tb;

    // ── DUT signals ───────────────────────────
    reg        clk;
    reg        rst;
    reg        valid_in;
    reg [15:0] data_in;
    wire       valid_out;
    wire [15:0] data_out;

    // ── Test tracking ─────────────────────────
    integer pass_count = 0;
    integer fail_count = 0;
    integer sample_num = 0;

    // ── Clock: 10ns = 100MHz ──────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── DUT Instantiation ─────────────────────
    fir_top dut (
        .clk       (clk),
        .rst       (rst),
        .valid_in  (valid_in),
        .data_in   (data_in),
        .valid_out (valid_out),
        .data_out  (data_out)
    );

    // ── Task: Send one sample ─────────────────
    task send_sample;
        input [15:0] sample;
        begin
            @(posedge clk);
            valid_in <= 1'b1;
            data_in  <= sample;
            @(posedge clk);
            valid_in <= 1'b0;
            data_in  <= 16'd0;
            // Wait for output
            @(posedge clk);
            sample_num = sample_num + 1;
            if (valid_out)
                $display("[TB] Sample %0d | IN=%0d | OUT=%0d",
                    sample_num, $signed(sample), $signed(data_out));
        end
    endtask

    // ── Task: Check output range ──────────────
    task check_range;
        input signed [15:0] val;
        input signed [15:0] lo;
        input signed [15:0] hi;
        input [63:0] test_name;
        begin
            if ($signed(val) >= lo && $signed(val) <= hi) begin
                $display("[PASS] %s: val=%0d in [%0d, %0d]",
                    test_name, $signed(val), lo, hi);
                pass_count = pass_count + 1;
            end
            else begin
                $display("[FAIL] %s: val=%0d NOT in [%0d, %0d]",
                    test_name, $signed(val), lo, hi);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ── Main Test Sequence ────────────────────
    integer j;
    initial begin
        // Waveform dump
        $dumpfile("sim/fir_waves.vcd");
        $dumpvars(0, fir_tb);

        $display("=========================================");
        $display(" FIR Filter — Simulation Start");
        $display("=========================================");

        // ── Apply Reset ───────────────────────
        rst      = 1;
        valid_in = 0;
        data_in  = 0;
        repeat(5) @(posedge clk);
        rst = 0;
        $display("[TB] Reset released");

        // ══════════════════════════════════════
        // TEST 1: Impulse Response
        // Send 1 impulse then zeros
        // Output should show filter coefficients
        // ══════════════════════════════════════
        $display("");
        $display("--- TEST 1: Impulse Response ---");
        send_sample(16'sd1000);     // impulse
        for (j = 0; j < 10; j = j+1)
            send_sample(16'sd0);    // zeros after impulse

        // ══════════════════════════════════════
        // TEST 2: DC Response
        // Constant input = 1000
        // Low-pass filter PASSES DC so output ~ 1000
        // ══════════════════════════════════════
        $display("");
        $display("--- TEST 2: DC Response ---");
        for (j = 0; j < 16; j = j+1)
            send_sample(16'sd1000);

        // Check last output is close to 1000
        check_range($signed(data_out), 16'sd800, 16'sd1200, "DC_RESP");

        // ══════════════════════════════════════
        // TEST 3: High Frequency Rejection
        // Alternating +1000, -1000 = Nyquist frequency
        // Low-pass filter BLOCKS this so output ~ 0
        // ══════════════════════════════════════
        $display("");
        $display("--- TEST 3: High Frequency Rejection ---");
        for (j = 0; j < 16; j = j+1) begin
            if (j % 2 == 0) send_sample(16'sd1000);
            else             send_sample(-16'sd1000);
        end

        // Check output is near zero
        check_range($signed(data_out), -16'sd200, 16'sd200, "HF_REJECT");

        // ══════════════════════════════════════
        // TEST 4: Step Response
        // Input goes from 0 to 1000 suddenly
        // Output should rise gradually (no instant jump)
        // ══════════════════════════════════════
        $display("");
        $display("--- TEST 4: Step Response ---");

        // Reset filter state first
        rst = 1;
        repeat(3) @(posedge clk);
        rst = 0;
        sample_num = 0;

        // Send zeros then step up to 1000
        for (j = 0; j < 4; j = j+1)
            send_sample(16'sd0);
        $display("[TB] Step: input jumps to 1000");
        for (j = 0; j < 12; j = j+1)
            send_sample(16'sd1000);

        // Check output reached DC value eventually
        check_range($signed(data_out), 16'sd700, 16'sd1300, "STEP_RESP");

        // ══════════════════════════════════════
        // FINAL RESULTS
        // ══════════════════════════════════════
        $display("");
        $display("=========================================");
        $display(" FIR FILTER TEST RESULTS");
        $display(" PASSED : %0d", pass_count);
        $display(" FAILED : %0d", fail_count);
        if (fail_count == 0)
            $display(" STATUS : ALL TESTS PASSED ✓");
        else
            $display(" STATUS : %0d TESTS FAILED ✗", fail_count);
        $display("=========================================");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #50000;
        $display("TIMEOUT");
        $finish;
    end

    // Continuous display when output valid
    always @(posedge clk) begin
        if (valid_out)
            $display("[WAVE] t=%0t IN=0x%04h OUT=0x%04h (%0d)",
                $time, data_in, data_out, $signed(data_out));
    end

endmodule
