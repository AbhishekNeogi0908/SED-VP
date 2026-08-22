#include <stdint.h>
#include "printf.h"

int main() {
  printf("\n==========================================\n");
  printf("=  SED-VP STABLE COMPRESS & EXPAND TEST  =\n");
  printf("==========================================\n\n");

  // 1. Allocate CSR arrays dynamically in software memory
  uint32_t rowptr[32] = {0};
  rowptr[4] = 0;
  rowptr[5] = 3;
  uint32_t colidx[3] = {101, 205, 309};
  uint32_t weights[3] = {1, 1, 1};

  // 2. Extract runtime memory addresses
  uint64_t rptr_addr = (uint64_t)rowptr;
  uint64_t cidx_addr = (uint64_t)colidx;
  uint64_t wgt_addr  = (uint64_t)weights;

  printf("Dynamic Memory Pointers:\n");
  printf("  - rowptr base:  0x%016llx\n", rptr_addr);
  printf("  - colidx base:  0x%016llx\n", cidx_addr);
  printf("  - weight base:  0x%016llx\n", wgt_addr);

  // 3. Load dynamic packed spike mask into v1
  uint32_t packed_spike_mask = (1 << 4) | (1 << 12);
  printf("\nLoading packed mask into Vector Register v1...\n");
  asm volatile (
      "vsetvli zero, %0, e32, m1, ta, ma \n"
      "vle32.v v1, (%1) \n"
      :: "r"(1), "r"(&packed_spike_mask)
  );

  // 4. Trigger Stage 1: Compression (sedvp.cidx) via vcompress.vm
  printf("Dispatching compressor trigger (vcompress.vm)...\n");
  asm volatile ("vcompress.vm v2, v3, v1");

  // 5. Trigger Stage 2: Expansion (sedvp.expand) via a safe vector mask instruction (vmor.mm)
  printf("Dispatching expander trigger (vmor.mm)...\n");
  asm volatile ("vmor.mm v4, v1, v1");

  printf("Waiting for SED-VP hardware pipeline completion...\n");
  for (volatile int i = 0; i < 2500; i++) {
      asm volatile ("nop");
  }

  printf("\nSoftware complete! Check terminal logs for clean execution.\n\n");
  return 0;
}