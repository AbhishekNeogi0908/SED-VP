#include <stdint.h>
#include "printf.h"

int main() {
  printf("\n==========================================\n");
  printf("=  SED-VP DYNAMIC SNN EXECUTION TEST     =\n");
  printf("==========================================\n\n");

  // 1. Define dynamic arrays in main memory
  // Creating a 32-element mask (1 = active, 0 = idle). 
  // Setting neurons 4 and 12 to 1 to match our expected hardware trace.
  uint32_t spike_mask[32] = {0};
  spike_mask[4] = 1;
  spike_mask[12] = 1;

  // 2. Define CSR arrays in memory to prepare for removing the dummy RAM
  uint32_t rowptr[32] = {0};
  rowptr[4] = 0;
  rowptr[5] = 3;
  uint32_t colidx[3] = {101, 205, 309};
  uint32_t weights[3] = {1, 1, 1};

  printf("1. Loading dynamic spike mask from memory into Vector Register v1...\n");
  
  // Use standard RVV instructions to load the mask array into v1
  asm volatile (
      "vsetvli zero, %0, e32, m1, ta, ma \n"
      "vle32.v v1, (%1) \n"
      :: "r"(32), "r"(spike_mask)
  );

  printf("2. Dispatching custom sedvp.cidx instruction...\n");
  
  // The hardware will soon read v1 instead of the dummy wire
  asm volatile ("vcompress.vm v2, v3, v1");

  printf("3. Waiting for hardware pipeline to process dynamic data...\n");
  
  for (volatile int i = 0; i < 1500; i++) {
      asm volatile ("nop");
  }

  printf("\n4. Test Complete! Check RTL logs for active IDs.\n\n");

  return 0;
}