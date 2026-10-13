`timescale 1ns / 1ps

module tb_top;

    import uvm_pkg::*;
    import butterfly_pkg::*;

    // 100MHz 클럭
    logic clk = 1'b0;
    always #5 clk = ~clk;

    // 실제 interface 인스턴스
    butterfly_if vif (
        .clk(clk)
    );

    // 검증 대상 Butterfly
    butterfly #(
        .DATA_WIDTH (20),
        .COEFF_WIDTH(16),
        .FRAC_BITS  (14),
        .T_WIDTH    (21)
    ) dut (
        .clk              (clk),
        .rst              (vif.rst),
        .i_read_data_valid(vif.i_read_data_valid),

        .a_re          (vif.a_re),
        .a_im          (vif.a_im),
        .b_re          (vif.b_re),
        .b_im          (vif.b_im),
        .twiddle_factor(vif.twiddle_factor),

        .y0_re(vif.y0_re),
        .y0_im(vif.y0_im),
        .y1_re(vif.y1_re),
        .y1_im(vif.y1_im),

        .o_bf_out_valid(vif.o_bf_out_valid)
    );

    // S0 내부 관측 신호 연결
    assign vif.a_re_s0  = dut.a_re_s0;
    assign vif.a_im_s0  = dut.a_im_s0;
    assign vif.b_re_s0  = dut.b_re_s0;
    assign vif.b_im_s0  = dut.b_im_s0;
    assign vif.twiddle_s0 = dut.twiddle_s0;
    assign vif.valid_s0 = dut.valid_s0;

    // 기존 interface에 선언된 곱셈기 관측 신호 연결
    // 현재 Monitor는 이 신호들을 전달하지 않음
    assign vif.t_re_comb = dut.t_re_comb;
    assign vif.t_im_comb = dut.t_im_comb;

    // S1 내부 관측 신호 연결
    assign vif.a_re_s1  = dut.a_re_s1;
    assign vif.a_im_s1  = dut.a_im_s1;
    assign vif.t_re_s1  = dut.t_re_s1;
    assign vif.t_im_s1  = dut.t_im_s1;
    assign vif.valid_s1 = dut.valid_s1;

    // S2 내부 valid 연결
    // S2 데이터는 DUT 출력 포트로 이미 연결됨
    assign vif.valid_s2 = dut.valid_s2;

    initial begin
        // Test, Driver, Monitor가 같은 interface에 접근
        uvm_config_db#(virtual butterfly_if)::set(
            null,
            "uvm_test_top",
            "vif",
            vif
        );

        uvm_config_db#(virtual butterfly_if)::set(
            null,
            "uvm_test_top.env.agent.*",
            "vif",
            vif
        );

        // 등록된 Butterfly Test 실행
        run_test("butterfly_test");
    end

endmodule