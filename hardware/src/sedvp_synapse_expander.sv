// Copyright 2026, SED-VP Architecture
// Module: CSR Synapse Expander with Self-Checking Diagnostics

module sedvp_synapse_expander import ara_pkg::*; (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Base Addresses for CSR Data Arrays (from Configuration CSRs)
    input  logic [63:0] rowptr_base_i,
    input  logic [63:0] colidx_base_i,
    input  logic [63:0] weight_base_i,

    // AEB Pop Interface
    output logic        aeb_pop_ready_o,
    input  logic        aeb_pop_valid_i,
    input  logic [63:0] aeb_pop_data_i, 

    // Memory Read Request Interface
    output logic        mem_req_o,
    output logic [63:0] mem_addr_o,
    input  logic [31:0] mem_rdata_i,
    input  logic        mem_rvalid_i,

    // Stream Output to Downstream Accumulator (QACC)
    output logic        qacc_valid_o,
    output logic [31:0] qacc_dst_id_o,
    output logic [15:0] qacc_weight_o,
    input  logic        qacc_ready_i
);

  typedef enum logic [2:0] {
    IDLE,
    FETCH_START_PTR,
    FETCH_END_PTR,
    FETCH_SYNAPSE
  } state_e;

  state_e state_d, state_q;

  logic [31:0] presyn_id_d, presyn_id_q;
  logic [31:0] ptr_start_d, ptr_start_q;
  logic [31:0] ptr_end_d,   ptr_end_q;
  logic [31:0] current_k_d, current_k_q;

  always_comb begin
    state_d         = state_q;
    presyn_id_d     = presyn_id_q;
    ptr_start_d     = ptr_start_q;
    ptr_end_d       = ptr_end_q;
    current_k_d     = current_k_q;

    aeb_pop_ready_o = 1'b0;
    mem_req_o       = 1'b0;
    mem_addr_o      = '0;
    qacc_valid_o    = 1'b0;
    qacc_dst_id_o   = '0;
    qacc_weight_o   = '0;

    case (state_q)
      IDLE: begin
        if (aeb_pop_valid_i) begin
          aeb_pop_ready_o = 1'b1;
          presyn_id_d     = aeb_pop_data_i[31:0]; 
          state_d         = FETCH_START_PTR;
          
          if (aeb_pop_ready_o) begin
            $display("[SED-VP EXPANDER] POP: Popped Presynaptic Event ID: %0d from AEB at cycle %0t", 
                     aeb_pop_data_i[31:0], $time);
          end
        end
      end

      FETCH_START_PTR: begin
        mem_req_o  = 1'b1;
        mem_addr_o = rowptr_base_i + (presyn_id_q * 4); 
        if (mem_rvalid_i) begin
          ptr_start_d = mem_rdata_i;
          current_k_d = mem_rdata_i;
          state_d     = FETCH_END_PTR;
        end
      end

      FETCH_END_PTR: begin
        mem_req_o  = 1'b1;
        mem_addr_o = rowptr_base_i + ((presyn_id_q + 1) * 4);
        if (mem_rvalid_i) begin
          ptr_end_d = mem_rdata_i;
          
          $display("[SED-VP EXPANDER] CSR BOUNDS: Presynaptic ID %0d -> Fan-out Range: [%0d to %0d)", 
                   presyn_id_q, ptr_start_q, mem_rdata_i);

          if (ptr_start_q == mem_rdata_i) begin
            $display("[SED-VP EXPANDER] NOTICE: Presynaptic ID %0d has 0 active outgoing synapses (Empty Row). Skipping.", presyn_id_q);
            state_d = IDLE;
          end else begin
            state_d = FETCH_SYNAPSE;
          end
        end
      end

      FETCH_SYNAPSE: begin
        mem_req_o  = 1'b1;
        mem_addr_o = colidx_base_i + (current_k_q * 4); 
        if (mem_rvalid_i) begin
          qacc_dst_id_o = mem_rdata_i;
          qacc_weight_o = 16'd1; 
          qacc_valid_o  = 1'b1;

          $display("[SED-VP EXPANDER] SUCCESS: Expanded Synapse k=%0d -> Postsynaptic Dst ID: %0d (Weight: +1) at cycle %0t", 
                   current_k_q, mem_rdata_i, $time);

          if (qacc_ready_i) begin
            if (current_k_q + 1 == ptr_end_q) begin
              state_d = IDLE; 
            end else begin
              current_k_d = current_k_q + 1;
            end
          end
        end
      end
    endcase
  end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
        state_q     <= IDLE;
        presyn_id_q <= '0;
        ptr_start_q <= '0;
        ptr_end_q   <= '0;
        current_k_q <= '0;
        end 
        else begin
        state_q     <= state_d;
        presyn_id_q <= presyn_id_d;
        ptr_start_q <= ptr_start_d;
        ptr_end_q   <= ptr_end_d;
        current_k_q <= current_k_d;

        // ---------------------------------------------------------
        // VERILATOR-SAFE DIAGNOSTIC PRINTS
        // ---------------------------------------------------------
        if (state_q == IDLE && aeb_pop_valid_i && aeb_pop_ready_o) begin
            $display("[SED-VP EXPANDER] POP: Popped Presynaptic Event ID: %0d from AEB at cycle %0t", 
                    aeb_pop_data_i[31:0], $time);
        end

        if (state_q == FETCH_END_PTR && mem_rvalid_i) begin
            $display("[SED-VP EXPANDER] CSR BOUNDS: Presynaptic ID %0d -> Fan-out Range: [%0d to %0d)", 
                    presyn_id_q, ptr_start_q, mem_rdata_i);
        end

        if (state_q == FETCH_SYNAPSE && mem_rvalid_i) begin
            $display("[SED-VP EXPANDER] SUCCESS: Expanded Synapse k=%0d -> Postsynaptic Dst ID: %0d (Weight: +1) at cycle %0t", 
                    current_k_q, mem_rdata_i, $time);
        end
        end
    end

endmodule