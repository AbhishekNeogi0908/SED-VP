// Copyright 2026, SED-VP Architecture
// Module: Active Event Compressor (sedvp.cidx)

module sedvp_cidx_compressor import ara_pkg::*; #(
    parameter int unsigned VLEN = 4096
) (
    input  logic             clk_i,
    input  logic             rst_ni,

    // Interface from Ara Sequencer
    input  logic             valid_i,
    input  logic [4:0]       vs2_i,       
    input  logic [4:0]       rs1_i,       

    // Interface to Vector Register File (VRF)
    output logic             vrf_req_o,
    output logic [4:0]       vrf_vreg_o,
    input  logic [VLEN-1:0]  vrf_mask_i,  
    input  logic             vrf_valid_i,

    // Interface to Active Event Buffer (AEB)
    output logic             aeb_valid_o,
    output logic [63:0]      aeb_data_o, // [63:32] = Row Cursor, [31:0] = Neuron ID
    input  logic             aeb_ready_i
);

  // FSM States
  typedef enum logic [1:0] { 
    IDLE,
    REQ_VRF, 
    WAIT_VRF, 
    COMPRESS } state_e;
  state_e state_d, state_q;

  logic [VLEN-1:0] mask_d, mask_q;
  logic [31:0]     current_idx_d, current_idx_q;

  always_comb begin
    // Default assignments to prevent latches
    state_d         = state_q;
    mask_d          = mask_q;
    current_idx_d   = current_idx_q;
    
    vrf_req_o       = 1'b0;
    vrf_vreg_o      = vs2_i; // Always target the vector register provided by the instruction
    
    aeb_valid_o     = 1'b0;
    aeb_data_o      = '0;

    case (state_q)
      IDLE: begin
        if (valid_i) begin
        //   vrf_req_o     = 1'b1;     // Ask VRF for the mask
          current_idx_d = '0;       // Reset our scanner index
          state_d       = WAIT_VRF;
        end
      end

      // NEW: Explicitly assert the request to Ara's operand_requester
      REQ_VRF: begin
        vrf_req_o = 1'b1;
        state_d   = WAIT_VRF;
      end

      WAIT_VRF: begin
        // vrf_req_o = 1'b1; // Keep requesting until we get valid data
        if (vrf_valid_i) begin
          mask_d  = vrf_mask_i;     // Latch the mask data
          state_d = COMPRESS;
        end
      end

      COMPRESS: begin
        if (mask_q == '0) begin
          // All 1s have been processed, return to IDLE
          state_d = IDLE;
        end else begin
          // Scan for active spikes (Simplified priority encoder)
          if (mask_q[0] == 1'b1) begin
            aeb_valid_o     = 1'b1;
            // Absolute ID = Base Offset (rs1) + logical index
            // Pack 32-bit row cursor (top) and 32-bit Neuron ID (bottom)
            aeb_data_o  = {32'd0, current_idx_q};
            
            if (aeb_ready_i) begin
              mask_d        = mask_q >> 1;
              current_idx_d = current_idx_q + 1;
            end
          end else begin
            // Skip the 0s (idle neurons)
            mask_d        = mask_q >> 1;
            current_idx_d = current_idx_q + 1;
          end
        end
      end

      default: state_d = IDLE; // Safety fallback
    endcase
  end

 // Sequential Logic (Flip-Flops) with Diagnostic Tracking
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q       <= IDLE;
      mask_q        <= '0;
      current_idx_q <= '0;
    end else begin
      state_q       <= state_d;
      mask_q        <= mask_d;
      current_idx_q <= current_idx_d;
      
      // Trace when the snooped mask is grabbed by the compressor
      if (state_q == WAIT_VRF && vrf_valid_i) begin
         $display("[SED-VP COMPRESSOR] TRACE @ Cycle %0t: Successfully latched mask payload: %h", 
                  $time, vrf_mask_i);
      end

      // Trace each active event ID pushed into the AEB
      if (state_q == COMPRESS && aeb_valid_o && aeb_ready_i) begin
         $display("[SED-VP COMPRESSOR] TRACE @ Cycle %0t: Found Active Bit! Pushed Neuron ID %0d to AEB", 
                  $time, current_idx_q);
      end
    end
  end

endmodule