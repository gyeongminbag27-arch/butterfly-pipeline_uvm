`ifndef BUTTERFLY_SCOREBOARD_SVH
`define BUTTERFLY_SCOREBOARD_SVH

class butterfly_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(butterfly_scoreboard)

    localparam int unsigned NUM_TRANSACTIONS = 1024;

    uvm_analysis_imp #(butterfly_item, butterfly_scoreboard) analysis_imp;
    uvm_analysis_port #(butterfly_item) verified_port;

    butterfly_item expected_s0, expected_s1, expected_s2;
    bit valid_s0 = 0, valid_s1 = 0, valid_s2 = 0;
    bit reset_seen = 0;
    bit input_started = 0;

    int unsigned accepted_count = 0;
    int unsigned completed_count = 0;
    int unsigned published_count = 0;
    int unsigned error_count = 0;
    int unsigned coverage_hits[4];

    bit [2:0] checked_stage[NUM_TRANSACTIONS];
    bit data_failed[NUM_TRANSACTIONS];
    bit valid_failed[NUM_TRANSACTIONS];
    bit timing_failed[NUM_TRANSACTIONS];
    bit input_continuous[NUM_TRANSACTIONS];
    bit published[NUM_TRANSACTIONS];
    bit [3:0] verified_checks_by_id[NUM_TRANSACTIONS];
    longint unsigned accept_cycle[NUM_TRANSACTIONS];
    longint unsigned first_input_cycle;

    function new(
        string name = "butterfly_scoreboard",
        uvm_component parent = null
    );
        super.new(name, parent);
        analysis_imp = new("analysis_imp", this);
        verified_port = new("verified_port", this);
        foreach (coverage_hits[i])
            coverage_hits[i] = 0;
    endfunction

    function void record_error(string tag, string message);
        error_count++;
        `uvm_error(tag, message)
    endfunction

    function butterfly_item make_expected(butterfly_item sample);
        butterfly_item exp;
        logic signed [63:0] ar, ai, br, bi, wr, wi;
        logic signed [63:0] raw_re, raw_im;
        logic signed [63:0] y0r, y0i, y1r, y1i;
        logic signed [20:0] tr, ti;

        exp = butterfly_item::type_id::create("expected");
        exp.a_re = sample.pre_a_re;
        exp.a_im = sample.pre_a_im;
        exp.b_re = sample.pre_b_re;
        exp.b_im = sample.pre_b_im;
        exp.twiddle_factor = sample.pre_twiddle;

        ar = sample.pre_a_re;
        ai = sample.pre_a_im;
        br = sample.pre_b_re;
        bi = sample.pre_b_im;
        wr = $signed(sample.pre_twiddle[31:16]);
        wi = $signed(sample.pre_twiddle[15:0]);

        raw_re = br * wr - bi * wi;
        raw_im = br * wi + bi * wr;
        tr = raw_re >>> 14;
        ti = raw_im >>> 14;

        exp.post_t_re_s1 = tr;
        exp.post_t_im_s1 = ti;
        y0r = ar + tr;
        y0i = ai + ti;
        y1r = ar - tr;
        y1i = ai - ti;
        exp.post_y0_re = y0r[19:0];
        exp.post_y0_im = y0i[19:0];
        exp.post_y1_re = y1r[19:0];
        exp.post_y1_im = y1i[19:0];
        return exp;
    endfunction

    // Record the comparison at the clock where this stage is observed.
    function void record_stage(
        butterfly_item exp,
        int unsigned stage,
        bit bad_data,
        bit bad_valid,
        longint unsigned cycle
    );
        int unsigned id;
        bit bad_timing;

        id = exp.transaction_id;
        if (id >= NUM_TRANSACTIONS || stage > 2) begin
            `uvm_fatal("BAD_STAGE", "Expected ID or stage out of range")
        end

        bad_timing = (cycle != accept_cycle[id] + stage);
        checked_stage[id][stage] = 1;
        data_failed[id] |= bad_data;
        valid_failed[id] |= bad_valid;
        timing_failed[id] |= bad_timing;

        if (bad_data || bad_valid || bad_timing) begin
            record_error(
                "STAGE",
                $sformatf(
                    "id=%0d stage=%0d cycle=%0d data_bad=%0b valid_bad=%0b timing_bad=%0b",
                    id, stage, cycle, bad_data, bad_valid, bad_timing
                )
            );
        end
    endfunction

    // Called once per ID, immediately after that ID's S2 comparison.
    // No final-phase loop, no unconditional 4'b1111 assignment.
    function void publish_result(
        butterfly_item exp,
        butterfly_item sample
    );
        butterfly_item result;
        int unsigned id;
        bit all_stages;
        bit output_continuous;
        bit [3:0] checks;

        id = exp.transaction_id;
        if (published[id]) begin
            record_error("DUPLICATE", $sformatf("Duplicate result: id=%0d", id));
            return;
        end

        all_stages = (checked_stage[id] == 3'b111);

        // Valid outputs must occupy first_input_cycle + 2 + ID.
        // Before counting this output, the observed output index must equal ID.
        output_continuous =
            (sample.post_out_valid === 1'b1) &&
            (sample.cycle_id == first_input_cycle + 2 + id) &&
            (completed_count == id);

        checks = '0;
        checks[0] = all_stages && !data_failed[id];
        checks[1] = checks[0] && !timing_failed[id] && !valid_failed[id];
        checks[2] = all_stages && !valid_failed[id];
        checks[3] = checks[1] && input_continuous[id] && output_continuous;

        verified_checks_by_id[id] = checks;
        published[id] = 1;
        published_count++;

        for (int unsigned i = 0; i < 4; i++) begin
            if (checks[i])
                coverage_hits[i]++;
        end

        if (!checks[3]) begin
            record_error(
                "CONTINUOUS",
                $sformatf("Continuous result check failed: id=%0d cycle=%0d", id, sample.cycle_id)
            );
        end

        result = butterfly_item::type_id::create($sformatf("verified_%0d", id));
        result.transaction_id = id;
        result.cycle_id = sample.cycle_id;
        result.verified_checks = checks;
        verified_port.write(result);

        `uvm_info(
            "VERIFIED",
            $sformatf("id=%0d cycle=%0d checks[3:0]=%04b", id, sample.cycle_id, checks),
            UVM_HIGH
        )
    endfunction

    virtual function void write(butterfly_item sample);
        bit bad_data_s0, bad_data_s1, bad_data_s2;
        bit bad_valid_s0, bad_valid_s1, bad_valid_s2;

        if ($isunknown(sample.pre_rst)) begin
            `uvm_fatal("RESET_X", "Reset contains X/Z")
        end

        if (sample.pre_rst === 1'b1) begin
            // The agreed test has initial reset only. Do not erase earlier bins.
            if (input_started) begin
                `uvm_fatal("UNEXPECTED_RESET", "Reset occurred after input processing started")
            end
            reset_seen = 1;
            expected_s0 = null;
            expected_s1 = null;
            expected_s2 = null;
            valid_s0 = 0;
            valid_s1 = 0;
            valid_s2 = 0;

            if ({
                sample.post_a_re_s0, sample.post_a_im_s0,
                sample.post_b_re_s0, sample.post_b_im_s0,
                sample.post_twiddle_s0,
                sample.post_a_re_s1, sample.post_a_im_s1,
                sample.post_t_re_s1, sample.post_t_im_s1,
                sample.post_y0_re, sample.post_y0_im,
                sample.post_y1_re, sample.post_y1_im,
                sample.post_valid_s0, sample.post_valid_s1,
                sample.post_valid_s2, sample.post_out_valid
            } !== '0) begin
                record_error("RESET", $sformatf("Reset mismatch: cycle=%0d", sample.cycle_id));
            end
            return;
        end

        if (!reset_seen) begin
            `uvm_fatal("NO_RESET", "Initial reset was not observed")
        end
        if ($isunknown(sample.pre_input_valid)) begin
            `uvm_fatal("VALID_X", "Input valid contains X/Z")
        end

        if (input_started && accepted_count < NUM_TRANSACTIONS &&
            sample.pre_input_valid !== 1'b1) begin
            record_error("INPUT_GAP", $sformatf("Input gap: cycle=%0d", sample.cycle_id));
        end

        if (sample.pre_input_valid === 1'b1) begin
            if (accepted_count >= NUM_TRANSACTIONS) begin
                `uvm_fatal("EXTRA_INPUT", "More than 1024 valid inputs observed")
            end
            if ($isunknown({sample.pre_a_re, sample.pre_a_im,
                           sample.pre_b_re, sample.pre_b_im, sample.pre_twiddle})) begin
                `uvm_fatal("INPUT_X", "Valid input contains X/Z")
            end
        end

        expected_s2 = expected_s1;
        expected_s1 = expected_s0;
        expected_s0 = null;
        valid_s2 = valid_s1;
        valid_s1 = valid_s0;
        valid_s0 = sample.pre_input_valid;

        if (valid_s0) begin
            if (!input_started)
                first_input_cycle = sample.cycle_id;
            input_started = 1;

            expected_s0 = make_expected(sample);
            expected_s0.transaction_id = accepted_count;
            accept_cycle[accepted_count] = sample.cycle_id;
            input_continuous[accepted_count] =
                (sample.cycle_id == first_input_cycle + accepted_count);
            accepted_count++;
        end

        bad_valid_s0 = (sample.post_valid_s0 !== valid_s0);
        bad_valid_s1 = (sample.post_valid_s1 !== valid_s1);
        bad_valid_s2 = (sample.post_valid_s2 !== valid_s2) ||
                       (sample.post_out_valid !== valid_s2);

        if (bad_valid_s0 || bad_valid_s1 || bad_valid_s2) begin
            record_error("VALID", $sformatf("Valid mismatch: cycle=%0d", sample.cycle_id));
        end

        bad_data_s0 = ({sample.post_a_re_s0, sample.post_a_im_s0,
                        sample.post_b_re_s0, sample.post_b_im_s0, sample.post_twiddle_s0}
                   !== {sample.pre_a_re, sample.pre_a_im,
                        sample.pre_b_re, sample.pre_b_im, sample.pre_twiddle});

        if (valid_s0)
            record_stage(expected_s0, 0, bad_data_s0, bad_valid_s0, sample.cycle_id);
        else if (bad_data_s0)
            record_error("S0", $sformatf("S0 mismatch: cycle=%0d", sample.cycle_id));

        if (valid_s1) begin
            bad_data_s1 = ({sample.post_a_re_s1, sample.post_a_im_s1,
                            sample.post_t_re_s1, sample.post_t_im_s1}
                       !== {expected_s1.a_re, expected_s1.a_im,
                            expected_s1.post_t_re_s1, expected_s1.post_t_im_s1});
            record_stage(expected_s1, 1, bad_data_s1, bad_valid_s1, sample.cycle_id);
        end

        if (valid_s2) begin
            bad_data_s2 = ({sample.post_y0_re, sample.post_y0_im,
                            sample.post_y1_re, sample.post_y1_im}
                       !== {expected_s2.post_y0_re, expected_s2.post_y0_im,
                            expected_s2.post_y1_re, expected_s2.post_y1_im});
            record_stage(expected_s2, 2, bad_data_s2, bad_valid_s2, sample.cycle_id);

            // Real-time publication: this input's final comparison just finished.
            publish_result(expected_s2, sample);
        end

        // Count every actual valid output, including unexpected outputs.
        if (sample.post_out_valid === 1'b1)
            completed_count++;
    endfunction

    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (!reset_seen)
            record_error("NO_RESET", "Initial reset not observed");

        if (accepted_count != NUM_TRANSACTIONS ||
            completed_count != NUM_TRANSACTIONS ||
            published_count != NUM_TRANSACTIONS) begin
            record_error("COUNT", $sformatf(
                "Expected 1024: inputs=%0d outputs=%0d results=%0d",
                accepted_count, completed_count, published_count));
        end

        if (valid_s0 || valid_s1 || valid_s2)
            record_error("DRAIN", "Test ended before pipeline drained");

        foreach (checked_stage[i]) begin
            if (checked_stage[i] != 3'b111 || !published[i] ||
                verified_checks_by_id[i] != 4'b1111) begin
                record_error("TRANSACTION", $sformatf(
                    "Failed/incomplete ID=%0d stages=%03b checks=%04b published=%0b",
                    i, checked_stage[i], verified_checks_by_id[i], published[i]));
            end
        end

        for (int unsigned i = 0; i < 4; i++) begin
            if (coverage_hits[i] != NUM_TRANSACTIONS)
                record_error("HIT_COUNT", $sformatf("Check %0d hits=%0d expected=1024", i, coverage_hits[i]));
        end
        // No coverage publication here: final phase checks counts only.
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("VERIFIED_COUNTS", $sformatf(
            "storage=%0d movement=%0d valid=%0d continuous=%0d",
            coverage_hits[0], coverage_hits[1], coverage_hits[2], coverage_hits[3]), UVM_LOW)

        if (error_count == 0) begin
            `uvm_info("SCOREBOARD", "PASS: 1024 inputs; per-input checks published during S2 processing", UVM_LOW)
        end else begin
            `uvm_info("SCOREBOARD", $sformatf(
                "FAIL: inputs=%0d outputs=%0d results=%0d errors=%0d",
                accepted_count, completed_count, published_count, error_count), UVM_LOW)
        end
    endfunction

endclass

`endif
