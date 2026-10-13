`ifndef BUTTERFLY_TEST_SVH
`define BUTTERFLY_TEST_SVH

class butterfly_test extends uvm_test;

    `uvm_component_utils(butterfly_test)

    butterfly_env env;
    virtual butterfly_if vif;

    function new(
        string name = "butterfly_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env = butterfly_env::type_id::create("env", this);

        if (!uvm_config_db#(virtual butterfly_if)::get(
            this, "", "vif", vif
        )) begin
            `uvm_fatal("NO_VIF", "butterfly_if was not configured")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        butterfly_sequence seq;

        // 입력 전달 및 마지막 결과 관측까지 실행 유지
        phase.raise_objection(this);

        seq = butterfly_sequence::type_id::create("seq");

        // 초기 reset은 Driver에서 수행
        // Sequence는 랜덤 입력 1,024개 전달
        seq.start(env.agent.sequencer);

        // 마지막 입력 수락 후:
        // S1 이동 → S2 출력 → 출력 valid 해제까지 관측
        // 하강 에지에서 대기 종료해 Monitor의 관측 완료 보장
        repeat (4) @(negedge vif.clk);

        `uvm_info(
            "TEST",
            $sformatf(
                "Stimulus finished: inputs=%0d outputs=%0d",
                env.scoreboard.accepted_count,
                env.scoreboard.completed_count
            ),
            UVM_LOW
        )

        // 최종 PASS/FAIL은 Scoreboard의 check/report_phase에서 판정
        phase.drop_objection(this);
    endtask

endclass

`endif