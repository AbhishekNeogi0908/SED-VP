#include <stdint.h>
#include "printf.h"

int main() {
  printf("\n==========================================\n");
  printf("=  SED-VP DYNAMIC PACKED MASK TEST       =\n");
  printf("==========================================\n\n");

  // 1. Create a tightly packed 32-bit mask. 
  // Bit 4 and Bit 12 set to 1. Hex: 0x00001010
  uint32_t packed_spike_mask = (1 << 4) | (1 << 12);
  
  // 2. CSR arrays (Mock data for expansion)
  uint32_t rowptr[32] = {0};
  rowptr[4] = 0;
  rowptr[5] = 3;
  uint32_t colidx[3] = {101, 205, 309};
  uint32_t weights[3] = {1, 1, 1};

  printf("1. Mask created: 0x%08x\n", packed_spike_mask);
  printf("2. Loading packed mask into Vector Register v1...\n");
  
  // Load the packed 32-bit integer into v1
  asm volatile (
      "vsetvli zero, %0, e32, m1, ta, ma \n"
      "vle32.v v1, (%1) \n"
      :: "r"(1), "r"(&packed_spike_mask)
  );

  printf("3. Dispatching custom sedvp.cidx instruction...\n");
  asm volatile ("vcompress.vm v2, v3, v1");

  printf("4. Waiting for SED-VP hardware pipeline...\n");
  for (volatile int i = 0; i < 1500; i++) {
      asm volatile ("nop");
  }

  printf("\n5. Software complete! Check RTL logs.\n\n");
  return 0;
}