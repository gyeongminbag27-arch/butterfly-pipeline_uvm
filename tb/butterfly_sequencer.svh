`ifndef BUTTERFLY_SEQUENCER_SVH
`define BUTTERFLY_SEQUENCER_SVH

class butterfly_sequencer extends uvm_sequencer #(butterfly_item);

    `uvm_component_utils(butterfly_sequencer)

    function new(
        string name = "butterfly_sequencer",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

endclass

`endif