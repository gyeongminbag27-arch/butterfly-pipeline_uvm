`ifndef BUTTERFLY_ENV_SVH
`define BUTTERFLY_ENV_SVH

class butterfly_env extends uvm_env;

    `uvm_component_utils(butterfly_env)

    butterfly_agent      agent;
    butterfly_scoreboard scoreboard;
    butterfly_coverage coverage;

    function new(
        string name = "butterfly_env",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent = butterfly_agent::type_id::create(
            "agent", this
        );

        scoreboard = butterfly_scoreboard::type_id::create(
            "scoreboard", this
        );

        coverage = butterfly_coverage::type_id::create(
            "coverage", this
        );
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Monitor의 관측값을 Scoreboard로 전달
        agent.monitor.analysis_port.connect(
            scoreboard.analysis_imp
        );

         scoreboard.verified_port.connect(
            coverage.analysis_export
        );
    endfunction

endclass

`endif