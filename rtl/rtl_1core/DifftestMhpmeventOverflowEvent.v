
module DifftestMhpmeventOverflowEvent(
  input         clock,
  input         enable,
  input         io_valid,
  input  [63:0] io_mhpmeventOverflow,
  input  [ 7:0] io_coreid
);
`ifndef SYNTHESIS
`ifdef DIFFTEST

import "DPI-C" function void v_difftest_MhpmeventOverflowEvent (
  input   longint io_mhpmeventOverflow,
  input      byte io_coreid
);


  always @(posedge clock) begin
    if (enable)
      v_difftest_MhpmeventOverflowEvent (io_mhpmeventOverflow, io_coreid);
  end
`endif
`endif
endmodule
