`ifndef BUTTERFLY_MONITOR_SVH
`define BUTTERFLY_MONITOR_SVH

class butterfly_monitor extends uvm_monitor;

    `uvm_component_utils(butterfly_monitor)

    virtual butterfly_if vif;

    uvm_analysis_port #(butterfly_item) analysis_port;

    longint unsigned cycle_count = 0;

    function new(
        string name = "butterfly_monitor",
        uvm_component parent = null
    );
        super.new(name, parent);

        analysis_port = new("analysis_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual butterfly_if)::get(
            this, "", "vif", vif
        )) begin
            `uvm_fatal("NO_VIF", "butterfly_if was not configured")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        butterfly_item sample;

        forever begin
            // 同じ상승 에지의 post 샘플링 완료 대기
            @(vif.post_cb);

            // Driver용 req와 별개의 관측 객체
            sample = butterfly_item::type_id::create(
                $sformatf("sample_%0d", cycle_count)
            );

            sample.cycle_id = cycle_count;
            cycle_count++;

            // 실제 입력 관측
            sample.pre_rst         = vif.pre_cb.rst;
            sample.pre_input_valid = vif.pre_cb.i_read_data_valid;

            sample.pre_a_re    = vif.pre_cb.a_re;
            sample.pre_a_im    = vif.pre_cb.a_im;
            sample.pre_b_re    = vif.pre_cb.b_re;
            sample.pre_b_im    = vif.pre_cb.b_im;
            sample.pre_twiddle = vif.pre_cb.twiddle_factor;

            // 실제 S0 저장값 관측
            sample.post_a_re_s0    = vif.post_cb.a_re_s0;
            sample.post_a_im_s0    = vif.post_cb.a_im_s0;
            sample.post_b_re_s0    = vif.post_cb.b_re_s0;
            sample.post_b_im_s0    = vif.post_cb.b_im_s0;
            sample.post_twiddle_s0 = vif.post_cb.twiddle_s0;
            sample.post_valid_s0   = vif.post_cb.valid_s0;

            // 실제 S1 저장값 관측
            sample.post_a_re_s1  = vif.post_cb.a_re_s1;
            sample.post_a_im_s1  = vif.post_cb.a_im_s1;
            sample.post_t_re_s1  = vif.post_cb.t_re_s1;
            sample.post_t_im_s1  = vif.post_cb.t_im_s1;
            sample.post_valid_s1 = vif.post_cb.valid_s1;

            // 실제 S2 저장값과 valid 관측
            sample.post_y0_re = vif.post_cb.y0_re;
            sample.post_y0_im = vif.post_cb.y0_im;
            sample.post_y1_re = vif.post_cb.y1_re;
            sample.post_y1_im = vif.post_cb.y1_im;

            sample.post_valid_s2 = vif.post_cb.valid_s2;
            sample.post_out_valid = vif.post_cb.o_bf_out_valid;

            // 계산·판정 없이 관측 객체 전달
            analysis_port.write(sample);
        end
    endtask

endclass

`endif