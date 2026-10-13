`timescale 1ns / 1ps

module tb_top;

    import uvm_pkg::*;

    // 다음 단계에서 작성할 UVM package
    import butterfly_pkg::*;

    localparam integer DATA_WIDTH  = 20;
    localparam integer COEFF_WIDTH = 16;
    localparam integer FRAC_BITS   = 14;
    localparam integer T_WIDTH     = DATA_WIDTH + 1;

    // 10 ns 주기
    logic clk = 1'b0;
    always #5 clk = ~clk;

    // 기본 파라미터 사용:
    // 이후 UVM 클래스의 virtual butterfly_if 타입과 일치
    butterfly_if bus_if (
        .clk(clk)
    );

    butterfly #(
        .DATA_WIDTH (DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .FRAC_BITS  (FRAC_BITS),
        .T_WIDTH    (T_WIDTH)
    ) dut (
        .clk              (clk),
        .rst              (bus_if.rst),
        .i_read_data_valid(bus_if.i_read_data_valid),

        .a_re          (bus_if.a_re),
        .a_im          (bus_if.a_im),
        .b_re          (bus_if.b_re),
        .b_im          (bus_if.b_im),
        .twiddle_factor(bus_if.twiddle_factor),

        .y0_re(bus_if.y0_re),
        .y0_im(bus_if.y0_im),
        .y1_re(bus_if.y1_re),
        .y1_im(bus_if.y1_im),

        .o_bf_out_valid(bus_if.o_bf_out_valid)
    );

    //========================================================
    // 계층 참조: DUT 내부 신호 → interface 관측 신호
    //========================================================

    // S0
    assign bus_if.a_re_s0 = dut.a_re_s0;
    assign bus_if.a_im_s0 = dut.a_im_s0;
    assign bus_if.b_re_s0 = dut.b_re_s0;
    assign bus_if.b_im_s0 = dut.b_im_s0;

    assign bus_if.twiddle_s0 = dut.twiddle_s0;
    assign bus_if.valid_s0   = dut.valid_s0;

    // 곱셈기 조합 출력
    assign bus_if.t_re_comb = dut.t_re_comb;
    assign bus_if.t_im_comb = dut.t_im_comb;

    // S1
    assign bus_if.a_re_s1 = dut.a_re_s1;
    assign bus_if.a_im_s1 = dut.a_im_s1;
    assign bus_if.t_re_s1 = dut.t_re_s1;
    assign bus_if.t_im_s1 = dut.t_im_s1;

    assign bus_if.valid_s1 = dut.valid_s1;

    // S2
    assign bus_if.valid_s2 = dut.valid_s2;

    //========================================================
    // UVM에 virtual interface 전달
    //========================================================
initial begin
    // Test 본인에게 전달
    uvm_config_db#(virtual butterfly_if)::set(
        null,
        "uvm_test_top",
        "vif",
        bus_if
    );

    // Test 아래 Driver·Monitor에 전달
    uvm_config_db#(virtual butterfly_if)::set(
        null,
        "uvm_test_top.*",
        "vif",
        bus_if
    );

    run_test("butterfly_test");
end
endmodule

