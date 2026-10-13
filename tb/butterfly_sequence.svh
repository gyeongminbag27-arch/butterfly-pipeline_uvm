`ifndef BUTTERFLY_SEQUENCE_SVH
`define BUTTERFLY_SEQUENCE_SVH

class butterfly_sequence
    extends uvm_sequence #(butterfly_item);

    `uvm_object_utils(butterfly_sequence)

    localparam int unsigned NUM_TRANSACTIONS = 1024;

    function new(string name = "butterfly_sequence");
        super.new(name);
    endfunction

    virtual task body();
        butterfly_item req;

        for (int unsigned i = 0; i < NUM_TRANSACTIONS; i++) begin
            req = butterfly_item::type_id::create(
                $sformatf("req_%0d", i)
            );

            start_item(req);

            if (!req.randomize()) begin
                `uvm_fatal(
                    "RANDOMIZE",
                    $sformatf("Randomization failed: id=%0d", i)
                )
            end

            req.transaction_id = i;

            finish_item(req);
        end

        `uvm_info(
            "SEQUENCE",
            $sformatf(
                "Random stimulus completed: %0d transactions",
                NUM_TRANSACTIONS
            ),
            UVM_LOW
        )
    endtask

endclass

`endif