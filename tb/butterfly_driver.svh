`ifndef BUTTERFLY_DRIVER_SVH
`define BUTTERFLY_DRIVER_SVH

class butterfly_driver extends uvm_driver #(butterfly_item);

    `uvm_component_utils(butterfly_driver)

    virtual butterfly_if vif;

    int unsigned driven_count = 0;

    function new(
        string name = "butterfly_driver",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual butterfly_if)::get(
            this, "", "vif", vif
        )) begin
            `uvm_fatal("NO_VIF", "butterfly_if was not configured")
        end
    endfunction

    virtual task apply_reset();
        @(vif.drv_cb);

        vif.drv_cb.rst               <= 1'b1;
        vif.drv_cb.i_read_data_valid <= 1'b0;
        vif.drv_cb.a_re              <= '0;
        vif.drv_cb.a_im              <= '0;
        vif.drv_cb.b_re              <= '0;
        vif.drv_cb.b_im              <= '0;
        vif.drv_cb.twiddle_factor    <= '0;

        // 세 번의 상승 에지 동안 reset 유지
        repeat (3) @(posedge vif.clk);

        @(vif.drv_cb);
        vif.drv_cb.rst <= 1'b0;
    endtask

    virtual task run_phase(uvm_phase phase);
        butterfly_item req;

        apply_reset();

        forever begin
            seq_item_port.get_next_item(req);

            // 하강 에지에서 다음 입력 구동
            @(vif.drv_cb);

            vif.drv_cb.a_re           <= req.a_re;
            vif.drv_cb.a_im           <= req.a_im;
            vif.drv_cb.b_re           <= req.b_re;
            vif.drv_cb.b_im           <= req.b_im;
            vif.drv_cb.twiddle_factor <= req.twiddle_factor;

            // 처음 입력부터 연속으로 valid 유지
            vif.drv_cb.i_read_data_valid <= 1'b1;

            // 다음 상승 에지에서 DUT가 입력 수락
            @(posedge vif.clk);

            driven_count++;

            `uvm_info(
                "DRIVE",
                $sformatf(
                    "Input accepted: id=%0d count=%0d",
                    req.transaction_id, driven_count
                ),
                UVM_HIGH
            )

            seq_item_port.item_done();

            // 다음 하강 에지에 valid 해제 예약.
            // 다음 item이 있으면 그 에지에 다시 1로 구동.
            vif.drv_cb.i_read_data_valid <= 1'b0;
        end
    endtask

endclass

`endif