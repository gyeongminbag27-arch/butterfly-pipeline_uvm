`ifndef BUTTERFLY_AGENT_SVH
`define BUTTERFLY_AGENT_SVH

class butterfly_agent extends uvm_agent;

    `uvm_component_utils(butterfly_agent)

    butterfly_sequencer sequencer;
    butterfly_driver    driver;
    butterfly_monitor   monitor;

    function new(
        string name = "butterfly_agent",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sequencer = butterfly_sequencer::type_id::create(
            "sequencer", this
        );

        driver = butterfly_driver::type_id::create(
            "driver", this
        );

        monitor = butterfly_monitor::type_id::create(
            "monitor", this
        );
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Driver가 Sequencer에서 item을 받도록 연결
        driver.seq_item_port.connect(
            sequencer.seq_item_export
        );
    endfunction

endclass

`endif