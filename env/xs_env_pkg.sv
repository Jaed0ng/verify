
// Pre-processor macros
`include "uvm_macros.svh"
package xs_env_pkg;

   import uvm_pkg::*;
    
   // Constants / Structs / Enums

   // Objects
   `include "riscv_core_cfg.sv"

   // Environment components
   `include "riscv_core_refm.sv"
   `include "riscv_core_sb.sv"
   `include "riscv_core_env.sv"

endpackage : xs_env_pkg


