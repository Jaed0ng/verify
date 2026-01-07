
module DifftestCriticalErrorEvent(
  input         clock,
  input         enable,
  input         io_valid,
  input         io_criticalError,
  input  [ 7:0] io_coreid
);
`ifndef SYNTHESIS
`ifdef DIFFTEST

import "DPI-C" function void v_difftest_CriticalErrorEvent (
  input       bit io_criticalError,
  input      byte io_coreid
);


  always @(posedge clock) begin
    if (enable)
      v_difftest_CriticalErrorEvent (io_criticalError, io_coreid);
  end
`endif
`endif
endmodule
