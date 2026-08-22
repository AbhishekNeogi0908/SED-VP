// Copyright 2026, SED-VP Architecture
// Module: Active Event Buffer (AEB) FIFO Queue

module sedvp_aeb import ara_pkg::*; #(
    parameter int unsigned Depth = 128 // AEB size parameter[cite: 3]
) (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Push Interface (From Compressor)
    input  logic        push_valid_i,
    input  logic [63:0] push_data_i,  // 32-bit ID + 32-bit Row Cursor
    output logic        push_ready_o,

    // Pop Interface (To Synapse Expander)
    output logic        pop_valid_o,
    output logic [63:0] pop_data_o,
    input  logic        pop_ready_i
);

  // FIFO Storage: 64-bit wide entries
  logic [63:0] fifo_data_q [Depth];
  logic [7:0]  write_ptr_q, write_ptr_d;
  logic [7:0]  read_ptr_q, read_ptr_d;
  logic [7:0]  count_q, count_d;

  assign push_ready_o = (count_q < Depth);
  assign pop_valid_o  = (count_q > 0);
  assign pop_data_o   = fifo_data_q[read_ptr_q];

  always_comb begin
    write_ptr_d = write_ptr_q;
    read_ptr_d  = read_ptr_q;
    count_d     = count_q;

    // Handle Push (from Compressor)
    if (push_valid_i && push_ready_o) begin
      $display("[SED-VP AEB] SUCCESS: Queued 64-bit Event (ID/Cursor). Data: 0%h at cycle %0t", push_data_i, $time);
      write_ptr_d = (write_ptr_q + 1) % Depth;
      count_d     = count_d + 1;
    end

    // Handle Pop (from Expander)
    if (pop_valid_o && pop_ready_i) begin
      read_ptr_d = (read_ptr_q + 1) % Depth;
      count_d    = count_d - 1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      write_ptr_q <= '0;
      read_ptr_q  <= '0;
      count_q     <= '0;
    end else begin
      write_ptr_q <= write_ptr_d;
      read_ptr_q  <= read_ptr_d;
      count_q     <= count_d;
      if (push_valid_i && push_ready_o) begin
        fifo_data_q[write_ptr_q] <= push_data_i;
      end
    end
  end

endmodule