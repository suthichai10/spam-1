
//#!/usr/bin/iverilog -Ttyp -Wall -g2012 -gspecify -o test.vvp 
`include "../control/control.v"
`include "../pc/pc.v"
`include "../lib/assertion.v"
`include "../74245/hct74245.v"
`include "../74573/hct74573.v"
`include "../7474/hct7474.v"
`include "../74377/hct74377.v"
`include "../rom/rom.v"
`include "../ram/ram.v"
`include "../phaser/phaser.v"

// verilator lint_off ASSIGNDLY
// verilator lint_off STMTDLY

`timescale 1ns/1ns

module test();

    localparam SETTLE_TOLERANCE=50;

   `include "../lib/display_snippet.v"

    tri [15:0] address_bus;

    tri [7:0] rbus, lbus, alu_result_bus;
    wire [3:0] rbus_dev, lbus_dev;
    wire [4:0] targ_dev;
    wire [4:0] aluop;

    localparam _AMODE_NONE=3'b111;
    localparam _AMODE_PC=3'b011;
    localparam _AMODE_REG=3'b101;
    localparam _AMODE_IMM=3'b110;
    wire _addrmode_register, _addrmode_pc, _addrmode_immediate;
    wire [2:0] _addrmode = {_addrmode_pc, _addrmode_register, _addrmode_immediate}; 

    function automatic [4*8:0] sAddrMode();
        begin
         sAddrMode = !_addrmode_pc ? "pc" : !_addrmode_register?  "reg" : !_addrmode_immediate? "imm": "---";
        end
    endfunction


    localparam PHASE_NONE = 3'b000;
    localparam PHASE_FETCH = 3'b100;
    localparam PHASE_DECODE = 3'b010;
    localparam PHASE_EXEC = 3'b001;
    wire phaseFetch, phaseDecode, phaseExec, _phaseFetch;
    wire [2:0] phase = {phaseFetch, phaseDecode, phaseExec};

    function automatic [7*8:0] sPhase();
        begin
            sPhase = phaseFetch ? "fetch" : phaseDecode ? "decode" : phaseExec ?"exec": "---";
        end
    endfunction

    // CLOCK ===================================================================================
    localparam T=1000;

    logic clk;
    //always begin
    //   #CLOCK_INTERVAL clk = !clk;
    //end

    //wire #8 _clk = ! clk; // GATE + PD
    
    // RESET CIRCUIT ===================================================================================
    // "Do not use an asynchronous reset within your design." - https://zipcpu.com/blog/2017/08/21/rules-for-newbies.html

    logic _RESET_SWITCH;
    wire #9 RESET_SWITCH = ! _RESET_SWITCH;

    wire mrPC, _mrPC;

    hct7474 #(.BLOCKS(1), .LOG(1)) resetPCFF(
          ._SD(1'b1),
          ._RD(_RESET_SWITCH),
          .D(1'b1),
          .CP(phaseFetch),
          .Q(_mrPC),
          ._Q(mrPC)
        );

    // CLOCK PHASING ===================================================================================

    wire [9:0] seq;
    `define SEQ(x) (10'd2 ** (x-1))

    phaser #(.LOG(1)) ph(.clk, .mr(RESET_SWITCH), .seq, ._phaseFetch, .phaseFetch , .phaseDecode , .phaseExec);

    // CONTROL ===========================================================================================
   
    wire [7:0] control_byte;

  // instruction reg buffer
    hct74573 rom_inst_reg(
         .LE(phaseFetch), // data latches when fetch ends
         //._OE(_addrmode_immediate), // outputs turn on when 
         ._OE(1'b0), // always on
         .D(rom_hi.D),
         .Q(control_byte) // FIXME WIRE TO CONTROL LOGIC
    );

    control #(.LOG(1)) ctrl( 
                    .clk, 
                    ._mr(_mrPC), 
                    .ctrl(control_byte[7:5]), 
                    .phaseFetch, ._phaseFetch, .phaseDecode, .phaseExec, 
                    ._addrmode_pc, ._addrmode_register, ._addrmode_immediate, 
                    .rbus_dev, .lbus_dev, .targ_dev, .aluop
                    );

    wire [23:0] rom_data = {control_byte, rom_mid.D, rom_lo.D};

    logic op =0;

    // ops
    localparam op_dev_eq_xy_alu =0;
    localparam op_dev_eq_const8 =1;
    localparam op_dev_eq_const16 =2;
    localparam op_3_unused =3;
    localparam op_dev_eq_rom_immed =4;
    localparam op_dev_eq_ram_immed =5;
    localparam op_ram_immed_eq_dev =6;
    localparam op_7_unused =7;

    // sources
    localparam [3:0] dev_ram = 0;
    localparam [3:0] dev_rom = 1;
    localparam [3:0] dev_marlo = 2;

    // targets
    localparam [4:0] tdev_ram = {1'b0, dev_ram};
    localparam [4:0] tdev_rom = {1'b0, dev_rom};
    localparam [4:0] tdev_marlo = {1'b0, dev_marlo};

    // target device sel
    wire [7:0] tdev_eq_ram_in = {3'b0, tdev_ram};
    wire [7:0] tdev_from_instruction_in = {3'bz, rom_data[20:16]};
    wire [7:0] targ_dev_out = {3'bz, targ_dev};
    hct74245 tdev_from_instruction(.A(tdev_from_instruction_in), .B(targ_dev_out), .dir(1'b1), .nOE(! op == op_ram_immed_eq_dev));
    hct74245 tdev_eq_ram(.A(tdev_eq_ram_in), .B(targ_dev_out), .dir(1'b1), .nOE(! op == op_ram_immed_eq_dev));

    // l device sel
    assign lbus_dev = rom_data[12:9];
    
    // r device sel
    wire [7:0] rdev_from_instruction_aluop_in = {4'bz, rom_data[8:5]};
    wire [7:0] rdev_from_instruction_ramimmed_in = {4'bz, rom_data[19:16]};
    wire [7:0] rdev_eq_ram_in = {4'b0, dev_ram};
    wire [7:0] rdev_eq_rom_in = {4'b0, dev_rom};
    wire [7:0] lbus_dev_out = {4'bz, lbus_dev};

    hct74245 rdev_from_instruction_aluop(.A(rdev_from_instruction_aluop_in), .B(lbus_dev_out), .dir(1'b1), .nOE( !op == op_dev_eq_xy_alu));
    hct74245 rdev_from_instruction_ramimmed(.A(rdev_from_instruction_ramimmed_in), .B(lbus_dev_out), .dir(1'b1), .nOE(! op == op_ram_immed_eq_dev));
    hct74245 rdev_eq_ram(.A(rdev_eq_ram_in), .B(lbus_dev_out), .dir(1'b1), .nOE(!op == op_dev_eq_ram_immed));
    hct74245 rdev_eq_rom(.A(rdev_eq_rom_in), .B(lbus_dev_out), .dir(1'b1), .nOE(! (op == op_dev_eq_const8 | op == op_dev_eq_const16 | op == op_dev_eq_rom_immed)));
  
  
    // control lines for bufs need better names
    logic _rdev_rom=1; // put rom on rbus
    logic _ldev_marlo=1;
    logic _ldev_marhi=1;
    logic _rdev_marlo=1;
    logic _rdev_marhi=1;

    // control lines to write registers
    wire _pclo_in=1;
    wire _pc_in=1;
    wire _pchitmp_in=1;
    wire _marhi_in=1;
    wire _marlo_in=1;
                    

    // PROGRAM COUNTER ======================================================================================

    wire [7:0] PCHI, PCLO; // output of PC
    
    // PC reset is sync with +ve edge of clock
    pc #(.LOG(1))  PC (
        .clk(phaseFetch),
        ._MR(_mrPC),
        ._pc_in(_pc_in),
        ._pclo_in(_pclo_in),
        ._pchitmp_in(_pchitmp_in),
        .D(alu_result_bus),

        .PCLO(PCLO),
        .PCHI(PCHI)
    );

    hct74245 pchi_addrbushi_buf(.A(PCHI), .B(address_bus[15:8]), .dir(1'b1), .nOE(_addrmode_pc));
    hct74245 pclo_addrbuslo_buf(.A(PCLO), .B(address_bus[7:0]), .dir(1'b1), .nOE(_addrmode_pc));

    // ROM and IR =============================================================================================

    rom #(.AWIDTH(16), .Filename("hi.rom"))   rom_hi(._CS(1'b0), ._OE(1'b0), .A(address_bus));
    rom #(.AWIDTH(16), .Filename("mid.rom")) rom_mid(._CS(1'b0), ._OE(1'b0), .A(address_bus));
    rom #(.AWIDTH(16), .Filename("lo.rom"))   rom_lo(._CS(1'b0), ._OE(1'b0), .A(address_bus)); 
    
    hct74245 rom_rbus_buf(.A(rom_lo.D), .B(rbus), .dir(1'b1), .nOE(_rdev_rom));

    // immediate addressing buffer
    hct74573 rom_addrbushi_buf(
         .LE(phaseFetch), // data latches when fetch ends
         ._OE(_addrmode_immediate),
         .D(rom_mid.D),
         .Q(address_bus[15:8])
    );

    hct74573 rom_addrbuslo_buf(
         .LE(phaseFetch), // data latches when fetch ends
         ._OE(_addrmode_immediate), // outputs turn on when 
         .D(rom_lo.D),
         .Q(address_bus[7:0])
    );


    // MAR =============================================================================================
    hct74377 MARLO(._EN(_marlo_in), .CP(clk), .D(alu_result_bus));    
    hct74377 MARHI(._EN(_marhi_in), .CP(clk), .D(alu_result_bus));

    hct74245 marlo_lbus_buf(.A(MARLO.Q), .B(lbus), .dir(1'b1), .nOE(_ldev_marlo)); // optional
    hct74245 marlo_rbus_buf(.A(MARLO.Q), .B(rbus), .dir(1'b1), .nOE(_rdev_marlo)); // optional

    hct74245 marhi_lbus_buf(.A(MARHI.Q), .B(lbus), .dir(1'b1), .nOE(_ldev_marhi)); // optional
    hct74245 marhi_rbus_buf(.A(MARHI.Q), .B(rbus), .dir(1'b1), .nOE(_rdev_marhi)); // optional

    hct74245 marhi_addrbushi_buf(.A(MARHI.Q), .B(address_bus[15:8]), .dir(1'b1), .nOE(_addrmode_register));
    hct74245 marlo_addrbuslo_buf(.A(MARLO.Q), .B(address_bus[7:0]), .dir(1'b1), .nOE(_addrmode_register));



    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // TESTS ===========================================================================================
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    initial begin
        `ifndef verilator

        $dumpfile("dumpfile.vcd");
        $dumpvars(0, test);

        // $monitor ("%9t ", $time,  "TEST     ",
        //         //"rom=%08b:%08b:%08b", rom_hi.D, rom_mid.D, rom_lo.D, 
        //         //" seq=%-2d", nSeq,
        //         // " amode=%-3s", sAddrMode,
        //         // " addrbus=0x%4x", address_bus,
        //         " rbus=%8b lbus=%8b alu_result_bus=%8b", rbus, lbus, alu_result_bus,
        //         " rdev=%04b ldev=%04b targ=%05b aluop=%05b ", rbus_dev, lbus_dev, targ_dev, aluop,
        //         " PC=%02h:%02h", PCHI, PCLO,
        //         //"      %-s", label
        //         );

        `endif
    end

    integer count;
    integer p1count=3;
    integer p2count=5;

    always @(PCHI or PCLO) begin
      $display("");
      $display("%9t", $time, " PC=%-d >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>", {PCHI, PCLO});
    end

    task DUMP;
            $display ("%9t ", $time,  "DUMP     ",
                 "rom=%08b:%08b:%08b", rom_hi.D, rom_mid.D, rom_lo.D, 
                 " seq=%-2d", $clog2(seq)+1,
                 " amode=%-3s", sAddrMode(),
                 " addrbus=0x%4x", address_bus,
                 " FDE=%-s  %1b%1b%1b", sPhase(), phaseFetch, phaseDecode, phaseExec,
                 " rbus=%8b lbus=%8b alu_result_bus=%8b", rbus, lbus, alu_result_bus,
                 " rdev=%04b ldev=%04b targ=%05b aluop=%05b ", rbus_dev, lbus_dev, targ_dev, aluop,
                 " PC=%02h:%02h", PCHI, PCLO,
                 "      %-s", label
                 );
    endtask 

    always @* 
        if (_RESET_SWITCH)  
            $display("\n%9t RESET SWITCH RELEASE   _RESET_SWITCH=%1b  ======================================================================\n", $time, _RESET_SWITCH); 
        else      
            $display("\n%9t RESET SWITCH           _RESET_SWITCH=%1b  ======================================================================\n", $time, _RESET_SWITCH); 

    always @* 
        if (_mrPC)  
            $display("\n%9t PC RESET RELEASE   _mrPC=%1b  ======================================================================\n", $time, _mrPC); 
        else      
            $display("\n%9t PC RESET           _mrPC=%1b  ======================================================================\n", $time, _mrPC); 


    
    always @(*) begin
        $display("%9t", $time, " PHASE: FDE=%-s  %1b%1b%1b seq=%10b", sPhase(), phaseFetch, phaseDecode, phaseExec, seq); 
    end

    always @(*) begin
        $display("%9t", $time, " _AMODE: PRI=%-s  %1b%1b%1b seq=%10b", sAddrMode(), _addrmode_pc, _addrmode_register, _addrmode_immediate, seq); 
    end

    integer instCount = 0;
    always @(posedge phaseFetch) begin
        instCount ++;
        $display("\n%9t", $time, " PHASE: FETCH  INTRUCTION=%4d FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF", instCount); 
    end

    always @(posedge phaseDecode) begin
        $display("\n%9t", $time, " PHASE: DECODE DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"); 
    end

    always @(posedge phaseExec) begin
        $display("\n%9t", $time, " PHASE: EXEC  EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE"); 
    end

    always @* 
        $display ("%9t ", $time,  "ROM      rom=%08b:%08b:%08b", rom_hi.D, rom_mid.D, rom_lo.D, 
                " amode=%s", sAddrMode(),
                " addrbus=0x%4x", address_bus);
        
    always @* 
        $display("%9t ... seq=%-2d  %8b................", $time, $clog2(seq)+1, seq); 
        
    always @* 
        $display("%9t ", $time, "ROMBUFFS rom_addrbuslo_buf=0x%-2x", rom_addrbuslo_buf.data, 
            " rom_addrbus_hi_buf=0x%-2x", rom_addrbushi_buf.data,
            " rom_inst_reg=%8b", rom_inst_reg.data,
            " _oe=%1b(_addrmode_immediate)", _addrmode_immediate
            ); 

                
    always @* 
        $display("%9t ", $time, "DEVICE       ", 
                    "rdev=%04b ldev=%04b targ=%05b aluop=%05b ", rbus_dev, lbus_dev, targ_dev, aluop
        ); 

    always @* 
        $display("%9t ", $time, "ALU BUS ",
            " rbus=0x%-2x", rbus, 
            " lbus=0x%-2x", lbus,
            " alu_result_bus=%-2x", alu_result_bus
            ); 
        
    always @(posedge clk)
        $display("\n%9t", $time, " CLK  +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"); 
        
    always @(negedge clk)
        $display("\n%9t", $time, " CLK  -----------------------------------------------------------------------\n"); 
        
    // constraints
    always @(*) begin
        if (phaseDecode & control_byte === 'x) begin
            $display("rom_hi.D", rom_hi.D); 
            $display("control_byte", control_byte); 
            DUMP;
            $display("END OF PROGRAM - CONTROL BYTE = XX "); 
            $finish();
        end
    end

    // constraints
    always @* begin
        // permits a situation where the control lines conflict.
        // this is ok as long as they settle quickly and are settled before exec phase.
        if (_RESET_SWITCH & phaseDecode) begin
            if (_addrmode_pc === 1'bx |  _addrmode_register === 1'bx |  _addrmode_immediate === 1'bx) begin
                $display("\n\n%9t ", $time, " ERROR ILLEGAL INDETERMINATE ADDR MODE _PC=%1b/_REG=%1b/_IMM=%1b", _addrmode_pc , _addrmode_register , _addrmode_immediate );
                #SETTLE_TOLERANCE
                if (_addrmode_pc === 1'bx |  _addrmode_register === 1'bx |  _addrmode_immediate === 1'bx) begin
                    DUMP;
                    $display("\n\n%9t ", $time, " ABORT");
                    $finish();
                end
            end
            // only one may be low at a time
            if (_addrmode_pc + _addrmode_register + _addrmode_immediate < 2) begin
                $display("\n\n%9t ", $time, " ERROR CONFLICTING ADDR MODE _PC=%1b/_REG=%1b/_IMM=%1b sAddrMode=%-s", _addrmode_pc , _addrmode_register , _addrmode_immediate, sAddrMode());
                #SETTLE_TOLERANCE
                if (_addrmode_pc + _addrmode_register + _addrmode_immediate < 2) begin
                    DUMP;
                    $display("\n\n%9t ", $time, " ABORT");
                    $finish();
                end
            end
        end
    end

    // tests
    initial begin
        localparam T=1000;   // clock cycle

        `DISPLAY("init : _RESET_SWITCH=0")
        _RESET_SWITCH <= 0;
        clk <= 0;

        #T
        `Equals( phase, PHASE_NONE)

        `Equals( seq, `SEQ(1))
        `Equals( _addrmode, 3'b1xx)

        `Equals(PCHI, 8'bx)
        `Equals(PCLO, 8'bx)

        `Equals(address_bus, 16'bx);

        #T
        `DISPLAY("_mrPC=0  - so clocking is ineffective = stay in PC addressing mode")
        `Equals( _mrPC, 0);

        count = 0;
        while (count++ < 3) begin
            #T
            clk <= 1;
            #T
            clk <= 0;
        end
        #T
        `Equals(PCHI, 8'bx)
        `Equals(PCLO, 8'bx)
        

        `DISPLAY("_RESET_SWITCH released : still in PC addressing mode after settle and PC=0")
        _RESET_SWITCH <= 1;
        `Equals( _mrPC, 0);
        `Equals( phase, PHASE_NONE)
        #T
        `Equals( phase, PHASE_FETCH)
        `Equals( _addrmode, _AMODE_PC);
        `Equals( _mrPC, 1'b1); // +clock due to phaseFetch on SR plus the release of the reset on the SR
        `Equals(PCHI, 8'b0) 
        `Equals(PCLO, 8'b0)
        `Equals(address_bus, 16'h0000);
        `Equals( seq, `SEQ(1));
        
        `DISPLAY("clock 1")
        clk <= 1;
        #T
        clk <= 0;
        #T
        `Equals( phase, PHASE_FETCH)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b0)
        `Equals( _addrmode, _AMODE_PC);
        `Equals(address_bus, 16'h0000);
        `Equals( seq, `SEQ(2));

        `DISPLAY("clock 2")
        clk <= 1;
        #T
        clk <= 0;
        #T
        `Equals( phase, PHASE_FETCH)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b0)
        `Equals( _addrmode, _AMODE_PC);
        `Equals(address_bus, 16'h0000);
        `Equals( seq, `SEQ(3));

        `DISPLAY("clock 3")
        clk <= 1;
        #T
        clk <= 0;
        #T
        `Equals( phase, PHASE_FETCH)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b0)
        `Equals( _addrmode, _AMODE_PC);
        `Equals(address_bus, 16'h0000);
        `Equals( seq, `SEQ(4));

        `DISPLAY("clock 4")
        clk <= 1;
        #T
        clk <= 0;
        #T
        `Equals( phase, PHASE_DECODE)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b0)
        `Equals( _addrmode, _AMODE_IMM);
        `Equals(address_bus, 16'h2211); // FROM ROM[15:0] 
        `Equals( seq, `SEQ(5));

        `DISPLAY("clock 5")
        clk <= 1;
        #T
        clk <= 0;
        #T
        `Equals( phase, PHASE_DECODE)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b0)
        `Equals( _addrmode, _AMODE_IMM);
        `Equals(address_bus, 16'h2211); // FROM ROM[15:0] 
        `Equals( seq, `SEQ(6));

        `DISPLAY("clock 6")
        clk <= 1;
        #T
        clk <= 0;
        #T
        `Equals( phase, PHASE_DECODE)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b0)
        `Equals( _addrmode, _AMODE_IMM);
        `Equals(address_bus, 16'h2211); // FROM ROM[15:0] 
        `Equals( seq, `SEQ(7));

        `DISPLAY("clock 7")
        clk <= 1;
        #T
        clk <= 0;
        #T
        `Equals( phase, PHASE_DECODE)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b0)
        `Equals( _addrmode, _AMODE_IMM);
        `Equals(address_bus, 16'h2211); // FROM ROM[15:0] 
        `Equals( seq, `SEQ(8));

        `DISPLAY("clock 8")
        clk <= 1;
        #T
        clk <= 0;
        #T
        `Equals( phase, PHASE_EXEC)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b0)
        `Equals( _addrmode, _AMODE_IMM);
        `Equals(address_bus, 16'h2211); // FROM ROM[15:0] 
        `Equals( seq, `SEQ(9));

        `DISPLAY("clock 9")
        #1
        clk <= 1;
        #T
        `Equals( phase, PHASE_EXEC)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b0)
        `Equals( _addrmode, _AMODE_IMM);
        `Equals(address_bus, 16'h2211); // FROM ROM[15:0] 
        `Equals( seq, `SEQ(10));
        clk <= 0;
        #T

        `DISPLAY("clock 10 ----- NEXT CYCLE STARTS")
        clk <= 1;
        #T
        `Equals( phase, PHASE_FETCH)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b1)
        `Equals( _addrmode, _AMODE_PC);
        `Equals(address_bus, 16'h0001); // FROM PC
        `Equals( seq, `SEQ(1));
        clk <= 0;
        #T

        `DISPLAY("clock 11")
        clk <= 1;
        #T
        `Equals( phase, PHASE_FETCH)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b1)
        `Equals( _addrmode, _AMODE_PC);
        `Equals(address_bus, 16'h0001); // FROM PC
        `Equals( seq, `SEQ(2));
        clk <= 0;
        #T

        `DISPLAY("clock 12")
        clk <= 1;
        #T
        `Equals( phase, PHASE_FETCH)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b1)
        `Equals( _addrmode, _AMODE_PC);
        `Equals(address_bus, 16'h0001); // FROM PC
        `Equals( seq, `SEQ(3));
        clk <= 0;
        #T

        `DISPLAY("clock 13")
        clk <= 1;
        #T
        `Equals( phase, PHASE_FETCH)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b1)
        `Equals( _addrmode, _AMODE_PC);
        `Equals(address_bus, 16'h0001); // FROM PC
        `Equals( seq, `SEQ(4));
        clk <= 0;
        #T

        `DISPLAY("clock 14")
        clk <= 1;
        #T
        `Equals( phase, PHASE_DECODE)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b1)
        `Equals( _addrmode, _AMODE_REG);
        `Equals(address_bus, 16'hx); // FROM MAR -- WRITE TO MAR NOT IMPLE
        `Equals( seq, `SEQ(5));
        clk <= 0;
        #T

        `DISPLAY("clock 15")
        clk <= 1;
        #T
        `Equals( phase, PHASE_DECODE)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b1)
        `Equals( _addrmode, _AMODE_REG);
        `Equals(address_bus, 16'hx); // FROM MAR ---- WRITE TO MAR NOT IMPL
        `Equals( seq, `SEQ(6));
        clk <= 0;
        #T

        `DISPLAY("clock 16")
        clk <= 1;
        #T
        `Equals( phase, PHASE_DECODE)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b1)
        `Equals( _addrmode, _AMODE_REG);
        `Equals(address_bus, 16'hx); // FROM MAR ---- WRITE TO MAR NOT IMPL
        `Equals( seq, `SEQ(7));
        clk <= 0;
        #T

        `DISPLAY("clock 17")
        clk <= 1;
        #T
        `Equals( phase, PHASE_DECODE)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b1)
        `Equals( _addrmode, _AMODE_REG);
        `Equals(address_bus, 16'hx); // FROM MAR ---- WRITE TO MAR NOT IMPL
        `Equals( seq, `SEQ(8));
        clk <= 0;
        #T

        `DISPLAY("clock 18")
        clk <= 1;
        #T
        `Equals( phase, PHASE_EXEC)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b1)
        `Equals( _addrmode, _AMODE_REG);
        `Equals(address_bus, 16'hx); // FROM MAR
        `Equals( seq, `SEQ(9));
        clk <= 0;
        #T

        `DISPLAY("clock 18")
        clk <= 1;
        #T
        `Equals( phase, PHASE_EXEC)
        `Equals(PCHI, 8'b0)
        `Equals(PCLO, 8'b1)
        `Equals( _addrmode, _AMODE_REG);
        `Equals(address_bus, 16'hx); // FROM MAR
        `Equals( seq, `SEQ(10));
        clk <= 0;
        #T



//`include "./generated_tests.v"
/*
        #T
        count=100;
        while (count -- > 0) begin
            #T
            clk <= 1;
            #T
            clk <= 0;
            $display("PC %2x:%2x !!!!!!!!!!!!!!!!!!!!!!!! CLK COUNT REMAINING=%-d", PCHI, PCLO, count);
        end
*/
        $display("END OF TEST");
        $finish();

    end

endmodule : test
