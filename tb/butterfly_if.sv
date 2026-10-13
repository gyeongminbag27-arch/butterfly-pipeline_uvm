`timescale 1ns / 1ps

interface butterfly_if #(
    parameter integer DATA_WIDTH  = 20,
    parameter integer COEFF_WIDTH = 16,
    parameter integer T_WIDTH     = DATA_WIDTH + 1
)(
    input logic clk
);

    // DUT 입력: driver가 구동
    logic rst = 1'b1;
    logic i_read_data_valid = 1'b0;

    logic signed [DATA_WIDTH-1:0] a_re = '0;
    logic signed [DATA_WIDTH-1:0] a_im = '0;
    logic signed [DATA_WIDTH-1:0] b_re = '0;
    logic signed [DATA_WIDTH-1:0] b_im = '0;
    logic [2*COEFF_WIDTH-1:0] twiddle_factor = '0;

    // DUT 출력
    wire signed [DATA_WIDTH-1:0] y0_re, y0_im;
    wire signed [DATA_WIDTH-1:0] y1_re, y1_im;
    wire o_bf_out_valid;

    // S0 내부 관측
    wire signed [DATA_WIDTH-1:0] a_re_s0, a_im_s0;
    wire signed [DATA_WIDTH-1:0] b_re_s0, b_im_s0;
    wire [2*COEFF_WIDTH-1:0] twiddle_s0;
    wire valid_s0;

    // 곱셈기 조합 출력 관측
    wire signed [T_WIDTH-1:0] t_re_comb, t_im_comb;

    // S1 내부 관측
    wire signed [DATA_WIDTH-1:0] a_re_s1, a_im_s1;
    wire signed [T_WIDTH-1:0] t_re_s1, t_im_s1;
    wire valid_s1;

    // S2 내부 valid 관측
    // S2 데이터는 y0/y1 출력으로 관측
    wire valid_s2;

    // 하강 에지에서 입력 변경 → 다음 상승 에지에서 DUT가 수락
    clocking drv_cb @(negedge clk);
        default input #1step output #0;

        output rst;
        output i_read_data_valid;
        output a_re, a_im, b_re, b_im;
        output twiddle_factor;
    endclocking

    // 상승 에지 직전 값 관측:
    // 이번 에지에서 각 레지스터가 저장해야 할 값
    clocking pre_cb @(posedge clk);
        default input #1step;

        input rst;
        input i_read_data_valid;
        input a_re, a_im, b_re, b_im;
        input twiddle_factor;

        input a_re_s0, a_im_s0;
        input b_re_s0, b_im_s0;
        input twiddle_s0, valid_s0;

        input t_re_comb, t_im_comb;
        input a_re_s1, a_im_s1;
        input t_re_s1, t_im_s1, valid_s1;
    endclocking

    // 상승 에지의 nonblocking 대입 반영 후 관측:
    // 실제로 저장된 값
    clocking post_cb @(posedge clk);
        default input #0;

        input a_re_s0, a_im_s0;
        input b_re_s0, b_im_s0;
        input twiddle_s0, valid_s0;

        input a_re_s1, a_im_s1;
        input t_re_s1, t_im_s1, valid_s1;

        input y0_re, y0_im, y1_re, y1_im;
        input valid_s2, o_bf_out_valid;
    endclocking

      



endinterface