`ifndef BUTTERFLY_COVERAGE_SVH
`define BUTTERFLY_COVERAGE_SVH

class butterfly_coverage extends uvm_subscriber #(butterfly_item);

    `uvm_component_utils(butterfly_coverage)

    localparam int unsigned NUM_TRANSACTIONS = 1024;

   

    // ID별 결과 수신 여부와 실제 통과 항목
    bit received[NUM_TRANSACTIONS];
    bit [3:0] recorded_checks[NUM_TRANSACTIONS];

    int unsigned received_count = 0;
    int unsigned hit_count[4];

    covergroup verified_cg with function sample(
        int unsigned id,
        int unsigned check_index
    );
        option.per_instance = 1;

        cp_id: coverpoint id {
            bins input_id[1024] = {[0:1023]};
        }

        cp_check: coverpoint check_index {
            bins storage    = {0};
            bins movement   = {1};
            bins valid      = {2};
            bins continuous = {3};
        }

        id_x_check: cross cp_id, cp_check;

    endgroup

    function new(
        string name = "butterfly_coverage",
        uvm_component parent = null
    );
        super.new(name, parent);

        verified_cg = new();

        foreach (hit_count[i])
            hit_count[i] = 0;
    endfunction

   

    // 各입력의 S2 검사가 끝난 클럭에 호출됨
    virtual function void write(butterfly_item t);
        int unsigned id;

        if (t == null) begin
            `uvm_error("COVERAGE_NULL", "Null result received")
            return;
        end

        id = t.transaction_id;

        if (id >= NUM_TRANSACTIONS) begin
            `uvm_error(
                "COVERAGE_ID",
                $sformatf("Transaction ID out of range: %0d", id)
            )
            return;
        end

        // 동일 입력의 결과를 두 번 누적하지 않음
        if (received[id]) begin
            `uvm_error(
                "COVERAGE_DUPLICATE",
                $sformatf("Duplicate result: id=%0d", id)
            )
            return;
        end

        received[id] = 1;
        received_count++;
        recorded_checks[id] = t.verified_checks;


        // 통과한 항목만 해당 ID의 bin을 채움
        for (int unsigned i = 0; i < 4; i++) begin
            if (t.verified_checks[i]) begin
                verified_cg.sample(id, i);
                hit_count[i]++;
            end
        end

        `uvm_info(
            "COVERAGE_SAMPLE",
            $sformatf(
                "id=%0d cycle=%0d checks[3:0]=%04b",
                id, t.cycle_id, t.verified_checks
            ),
            UVM_HIGH
        )
    endfunction

    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        if (received_count != NUM_TRANSACTIONS) begin
            `uvm_error(
                "COVERAGE_COUNT",
                $sformatf(
                    "Expected 1024 results, received=%0d",
                    received_count
                )
            )
        end

        for (int unsigned i = 0; i < 4; i++) begin
            if (hit_count[i] != NUM_TRANSACTIONS) begin
                `uvm_error(
                    "COVERAGE_HITS",
                    $sformatf(
                        "Check %0d: hits=%0d expected=1024",
                        i, hit_count[i]
                    )
                )
            end
        end

       
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info(
            "COVERAGE",
            $sformatf(
                "Results=%0d storage=%0d movement=%0d valid=%0d continuous=%0d coverage=%0.2f%%",
                received_count,
                hit_count[0],
                hit_count[1],
                hit_count[2],
                hit_count[3],
                verified_cg.get_inst_coverage()
            ),
            UVM_LOW
        )
    endfunction

endclass

`endif