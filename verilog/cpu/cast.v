
`ifndef V_CAST
`define  V_CAST
`timescale 1ns/1ns
module cast();

    function [3:0] to4([3:0] IN);
        to4 = IN;
    endfunction  
    function [4:0] to5([4:0] IN);
        to5 = IN;
    endfunction  
    function [7:0] to8([7:0] IN);
        to8 = IN;
    endfunction  
    function [15:0] to16([15:0] IN);
        to16 = IN;
    endfunction  

endmodule
`endif
