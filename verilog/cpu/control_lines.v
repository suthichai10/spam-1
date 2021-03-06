// FIXME MAKE ALL THE tri WIRES tri0
//
// CONSTANTS AND FUNCTIONS AND MACROS
//

`ifndef V_CONTROL
`define V_CONTROL

`define DECODE_PHASES   (phaseFetch ? "fetch" : phaseExec? "exec": "---")
`define DECODE_PHASE   logic [6*8-1:0] sPhase; assign sPhase = `DECODE_PHASES;

// unlike an assign this executes instantaneously but not referentially transparent
`define DECODE_ADDRMODES (!_addrmode_register?  "register" : !_addrmode_direct? "direct": "--") 
`define DECODE_ADDRMODE  logic [9*8-1:0] sAddrMode; assign sAddrMode = `DECODE_ADDRMODES;

`define toDEV(DEVNAME) control::DEV_``DEVNAME``

`define AMODE_TUPLE    wire [1:0] _addrmode = {CPU._addrmode_register, CPU._addrmode_direct}; 

// verilator lint_off ASSIGNDLY
// verilator lint_off STMTDLY
// verilator lint_off MULTITOP
// verilator lint_off DECLFILENAME
// verilator lint_off DISABLED-UNUSED
`timescale 1ns/1ns

package control;
 
    localparam PHASE_NONE = 2'b00;
    localparam PHASE_FETCH = 2'b10;
    localparam PHASE_EXEC = 2'b01;
   
    // see _addrmode_tuple
    localparam _AMODE_NONE=2'b11;
    localparam _AMODE_REG=2'b01;
    localparam _AMODE_DIR=2'b10;

    // sources or dests
    localparam [3:0] DEV_rega = 0; 
    localparam [3:0] DEV_regb = 1; 
    localparam [3:0] DEV_regc = 2; 
    localparam [3:0] DEV_regd = 3; 
    localparam [3:0] DEV_rege = 4; 
    localparam [3:0] DEV_regf = 5; 
    localparam [3:0] DEV_regg = 6; 
    localparam [3:0] DEV_regh = 7; 
    localparam [3:0] DEV_flags = 8;
    localparam [3:0] DEV_immed = 9; // READ FROM THE INSTRUCTION
    localparam [3:0] DEV_ram = 10;
    localparam [3:0] DEV_marlo = 11;
    localparam [3:0] DEV_marhi = 12;
    localparam [3:0] DEV_uart = 13;
    localparam [3:0] DEV_not_used = 14; // use for VIDEO RAM? need to add video ram to address bus
    localparam [3:0] DEV_not_used2 = 15;

    // dests only
    localparam [4:0] DEV_pchitmp = 16; // only load pchitmp
    localparam [4:0] DEV_pclo= 17; // only load pclo
    localparam [4:0] DEV_pc= 18;   // load pclo from instruction and load pchi from pchitmp
    localparam [4:0] DEV_jmpc= 19; // conditional version of "pc"
    localparam [4:0] DEV_jmpz= 20;
    localparam [4:0] DEV_jmpo= 21;
    localparam [4:0] DEV_jmpn= 22;
    localparam [4:0] DEV_jmpgt= 23;
    localparam [4:0] DEV_jmplt= 24;
    localparam [4:0] DEV_jmpeq= 25;
    localparam [4:0] DEV_jmpne= 26;
    localparam [4:0] DEV_jmpdi= 27;
    localparam [4:0] DEV_jmpdo= 28;
    localparam [4:0] DEV_nu1= 29;
    localparam [4:0] DEV_nu2= 30;
    localparam [4:0] DEV_nu3= 31;

    // targets
    function [4:0] TDEV([3:0] x);
        TDEV = {1'b0, x};
    endfunction

    // these can be src or dest
    `define TARGL(DNAME) localparam [4:0] TDEV_``DNAME`` = {1'b0, DEV_``DNAME``};

    // dest only
    `define TARGH(DNAME) localparam [4:0] TDEV_``DNAME`` = DEV_``DNAME``;

    // define constants
    `TARGL(ram)
    `TARGL(immed)
    `TARGL(marlo)
    `TARGL(marhi)
    `TARGL(uart)
    `TARGL(rega)
    `TARGL(regb)
    `TARGL(regc)
    `TARGL(regd)

    // 9-15 - todo
    `TARGH(pchitmp)
    `TARGH(pclo)
    `TARGH(pc)
    `TARGH(jmpc)
    `TARGH(jmpz)
    `TARGH(jmpo)
    `TARGH(jmpn)
    `TARGH(jmpgt)
    `TARGH(jmplt)
    `TARGH(jmpeq)
    `TARGH(jmpne)
    `TARGH(jmpdi)
    `TARGH(jmpdo)
    `TARGH(nu1)
    `TARGH(nu2)
    `TARGH(nu3)

    function string devname([3:0] dev); 
    begin
        case (dev)
            DEV_ram: devname = "RAM";
            DEV_not_used2: devname = "NOT_USED2";
            DEV_marlo: devname = "MARLO";
            DEV_marhi: devname = "MARHI";
            DEV_uart: devname = "UART";
            DEV_rega: devname = "REGA"; // 1
            DEV_regb: devname = "REGB"; // 2
            DEV_regc: devname = "REGC"; // 3
            DEV_regd: devname = "REGD"; // 4
            DEV_rege: devname = "REGE"; // 5
            DEV_regf: devname = "REGF"; // 6
            DEV_regg: devname = "REGG"; // 7
            DEV_regh: devname = "REGH"; // 8
            DEV_flags: devname = "FLAGS";
            DEV_not_used: devname = "NOT_USED";
            DEV_immed: devname = "IMMED";
            default: begin
                string n; 
                $sformat(n,"??(unknown %4b)", dev);
                devname = n;
            end
        endcase
    end
    endfunction    

    function string tdevname([4:0] tdev); 
    begin
        if (tdev[4] == 0) 
        begin 
            tdevname = devname(tdev[3:0]);
        end
        else 
        begin
            case (tdev)
                TDEV_pchitmp: tdevname = "PCHITMP";
                TDEV_pclo: tdevname = "PCLO";
                TDEV_pc: tdevname = "PC";
                TDEV_jmpc: tdevname = "JPMC";
                TDEV_jmpn: tdevname = "JPMN";
                TDEV_jmpo: tdevname = "JMPO";
                TDEV_jmpz: tdevname = "JMPZ";
                TDEV_jmpgt: tdevname = "JMPGT";
                TDEV_jmplt: tdevname = "JMPLT";
                TDEV_jmpeq: tdevname = "JMPEQ";
                TDEV_jmpne: tdevname = "JMPNE";
                TDEV_jmpdi: tdevname = "JMPDI";
                TDEV_jmpdo: tdevname = "JMPDO";
                TDEV_nu1: tdevname = "NU2";
                TDEV_nu2: tdevname = "NU2";
                TDEV_nu3: tdevname = "NU3";
                default: begin
                    string n; 
                    $sformat(n,"??(unknown %5b)", tdev);
                    tdevname = n;
                end
            endcase
        end
    end
    endfunction    

    function string fPhase(phaseFetch, phaseExec); 
    begin
            fPhase = `DECODE_PHASES;
    end
    endfunction

    function string fAddrMode(_addrmode_register, _addrmode_direct); 
    begin
            fAddrMode = `DECODE_ADDRMODES;
    end
    endfunction

endpackage: control

import control::*;


`define CONTROL_WIRES(FN, SEP)  \
    ```FN``_ADEV_SEL(flags)    SEP\
    ```FN``_ADEV_SEL(marhi)    SEP\
    ```FN``_ADEV_SEL(marlo)    SEP\
    ```FN``_ADEV_SEL(rega)    SEP\
    ```FN``_ADEV_SEL(regb)    SEP\
    ```FN``_ADEV_SEL(regc)    SEP\
    ```FN``_ADEV_SEL(regd)    SEP\
    ```FN``_ADEV_SEL(uart)    SEP\
    ```FN``_ADEV_SEL(not_used)    SEP\
    ```FN``_BDEV_SEL(immed)    SEP\
    ```FN``_BDEV_SEL(marhi)    SEP\
    ```FN``_BDEV_SEL(marlo)    SEP\
    ```FN``_BDEV_SEL(ram) SEP\
    ```FN``_BDEV_SEL(rega)    SEP\
    ```FN``_BDEV_SEL(regb)    SEP\
    ```FN``_BDEV_SEL(regc)    SEP\
    ```FN``_BDEV_SEL(regd)    SEP\
    ```FN``_BDEV_SEL(not_used2)    SEP\
    ```FN``_TDEV_SEL(jmpc)    SEP\
    ```FN``_TDEV_SEL(jmpdi)    SEP\
    ```FN``_TDEV_SEL(jmpdo)    SEP\
    ```FN``_TDEV_SEL(jmpeq)    SEP\
    ```FN``_TDEV_SEL(jmpgt)    SEP\
    ```FN``_TDEV_SEL(jmplt)    SEP\
    ```FN``_TDEV_SEL(jmpn)    SEP\
    ```FN``_TDEV_SEL(jmpne)    SEP\
    ```FN``_TDEV_SEL(jmpo)    SEP\
    ```FN``_TDEV_SEL(jmpz)    SEP\
    ```FN``_TDEV_SEL(marhi)    SEP\
    ```FN``_TDEV_SEL(marlo)    SEP\
    ```FN``_TDEV_SEL(pc)    SEP\
    ```FN``_TDEV_SEL(pchitmp)    SEP\
    ```FN``_TDEV_SEL(pclo)    SEP\
    ```FN``_TDEV_SEL(ram) SEP \
    ```FN``_TDEV_SEL(rega)    SEP\
    ```FN``_TDEV_SEL(regb)    SEP\
    ```FN``_TDEV_SEL(regc)    SEP\
    ```FN``_TDEV_SEL(regd)    SEP\
    ```FN``_TDEV_SEL(uart)    

`define SEMICOLON ;
`define COMMA ,

`define OUT_ADEV_SEL(DNAME) output _adev_``DNAME``
`define OUT_BDEV_SEL(DNAME) output _bdev_``DNAME``
`define OUT_TDEV_SEL(DNAME) output _``DNAME``_in

`endif

// verilator lint_on ASSIGNDLY
// verilator lint_on ASSIGNDLY
// verilator lint_on MULTITOP
