`ifndef BUTTERFLY_ITEM_SVH
`define BUTTERFLY_ITEM_SVH

class butterfly_item extends uvm_sequence_item;

    // Sequence / Driver용 랜덤 입력
    rand bit signed [19:0] a_re;
    rand bit signed [19:0] a_im;
    rand bit signed [19:0] b_re;
    rand bit signed [19:0] b_im;
    rand bit [31:0] twiddle_factor;

    int unsigned transaction_id;

    // Monitor / Scoreboard용 관측값
    longint unsigned cycle_id;

    // 상승 에지 직전 실제 입력
    logic pre_rst;
    logic pre_input_valid;

    logic signed [19:0] pre_a_re, pre_a_im;
    logic signed [19:0] pre_b_re, pre_b_im;
    logic [31:0] pre_twiddle;

    // 상승 에지 갱신 후 S0
    logic signed [19:0] post_a_re_s0, post_a_im_s0;
    logic signed [19:0] post_b_re_s0, post_b_im_s0;
    logic [31:0] post_twiddle_s0;
    logic post_valid_s0;

    // 상승 에지 갱신 후 S1
    logic signed [19:0] post_a_re_s1, post_a_im_s1;
    logic signed [20:0] post_t_re_s1, post_t_im_s1;
    logic post_valid_s1;

    // 상승 에지 갱신 후 S2
    logic signed [19:0] post_y0_re, post_y0_im;
    logic signed [19:0] post_y1_re, post_y1_im;
    logic post_valid_s2;
    logic post_out_valid;


    // Scoreboard / Coverage용 검증 완료 결과
    // [0]: 단계별 저장
    // [1]: 단계 이동
    // [2]: Valid 정렬
    // [3]: 연속 처리
    bit [3:0] verified_checks;

    // 기존 입력 필드만 자동화 매크로에 등록
    `uvm_object_utils_begin(butterfly_item)
        `uvm_field_int(a_re,           UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(a_im,           UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(b_re,           UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(b_im,           UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(twiddle_factor, UVM_DEFAULT | UVM_HEX)
        `uvm_field_int(transaction_id, UVM_DEFAULT | UVM_DEC)
    `uvm_object_utils_end

    function new(string name = "butterfly_item");
        super.new(name);
    endfunction

endclass

`endif