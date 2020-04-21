// UART Verilog for https://www.ftdichip.com/Support/Documents/DataSheets/Modules/DS_UM245R.pdf
/* verilator lint_off ASSIGNDLY */

`timescale 1ns/1ns
`define EOF 32'hFFFF_FFFF 
`define NULL 0 
`define NL 10

module um245r #(parameter T3=50, T4=1, T5=25, T6=80, T11=25, T12=80,
        INPUT_FILE="", OUTPUT_FILE="", INPUT_FILE_DEPTH=0, HEXMODE=0, LOG=0)  (
            inout [7:0] D,    // Input data
    input WR,        // Writes data on -ve edge
    input _RD,        // When goes from high to low then the FIFO data is placed onto D (equates to _OE)
 
    output _TXE,        // When high do NOT write data using WR, when low write data by strobing WR
    output _RXF        // When high to NOT read from D, when low then data is available to read by strobing RD low
);

function string strip;
    input string str; 
    begin
        strip = str;
        if (str.len() > 0) begin
            if (str[str.len()-1] == `NL) begin
                strip = str.substr(0, str.len()-2); 
            end
        end
    end
endfunction

/*if (str.len() > 0) begin
    if (str[str.len()-1] == `NL) begin
        str = str.substr(0, str.len()-2); 
    end
end
*/
localparam MAX_LINE_LENGTH=80;

logic _MR=0;

integer fOut=`NULL, fControl, c, r, txLength, tDelta;

reg [8*MAX_LINE_LENGTH:0] line; /* Line of text read from file */ 
reg [8*2:0] lineend; /* Line of text read from file */ 
reg TX_READY;
reg RX_READY;

integer verbose=0;
string str = "";
string str1 = "";

localparam BUFFER_SIZE=80;

//reg [8*BUFFER_SIZE:0] rxBuf; // Line of text read from file 
int rxBuf[BUFFER_SIZE]; // Line of text read from file 
int absWritePos = 0; // next place to write
int absReadPos = 0; // next place to read


wire #T11 dataAvailable = absReadPos < absWritePos;
wire spaceAvailable = (absWritePos - absReadPos) < BUFFER_SIZE;

reg [7:0] Drx = 'x;

always @* begin
    if (verbose)
    $display("%t UART:", $time, 
        " D=%8b", D, " WR=%1b", WR, " _RD=%1b", _RD, 
        " _RXF=%1b", _RXF, 
        " _TXE=%1b", _TXE, 
        " Drx=%8b", Drx,
        " ARPOS=%-3d", absReadPos,
        " AWPOS=%-3d", absWritePos,
        " RPOS=%-3d", absReadPos % BUFFER_SIZE,
        " WPOS=%-3d", absWritePos % BUFFER_SIZE,
        " DAVAIL=%1b", dataAvailable,
        " TX_READY=%1b", TX_READY, 
        " RX_READY=%1b", RX_READY
        );

end

integer tx_count=0;
assign _TXE = !(fOut != `NULL && TX_READY && tx_count > 0 && _MR);
assign _RXF = !(dataAvailable && RX_READY && _MR);
//assign _RXF = !(dataAvailable && RX_READY && _MR);

assign #T3 D= _RD? 8'bzzzzzzzz: dataAvailable ? Drx : 8'bxzxzxzxz;

/*
    Transmit only valid when _TXE is low.
    Transmit occurs when WR goes low.
*/
always @(negedge WR) begin
    if (_MR) begin
    if (_TXE) begin
            $display("%t ", $time, "UART: TRANSMITTING %8b", D);
            $display("%t ", $time, "UART: WR low while _TXE not ready");
            $finish_and_return(1);
    end

    if (verbose) $display("%t ", $time, "UART: TRANSMITTING 0x%02x (%c)", D, D);

    $fwrite(fOut, "%02x\n", D);
    $fflush(fOut);

    #T11 // -WR to _TXE inactive delay
    if (verbose) $display("%t ", $time, "UART: TX NOT READY");
    TX_READY=0; 

    tx_count --;
    if (tx_count < 0) begin
            $display("%t ", $time, "UART: tx_count went negative");
            $finish_and_return(1);
    end

    #T12 // min inactity period
    if (verbose) $display("TX INACTIVE PERIOD ENDS");
    TX_READY=1;

    end
end

/*
    Transmit only valid when _TXE is low.
    Transmit occurs when WR goes low.
*/
always @(negedge _RD) begin
    if (_MR) begin
    if (_RXF) begin
            $display("%t ", $time, "UART: _RD low while _RXF not ready");
            $finish_and_return(1);
    end

    if (! dataAvailable) begin
            $display("%t ", $time, "UART: _RD low while data not available");
            $finish_and_return(1);
    end

    //#T3 
    //$display("0 = %d", rxBuf[0]);
    //$display("1 = %d", rxBuf[1]);
    //$display("2 = %d", rxBuf[2]);

    if (verbose) $display("%t ", $time, "UART: READING AT %-d", absReadPos);
    Drx = rxBuf[absReadPos%BUFFER_SIZE];

    if (verbose) $display("%t ", $time, "UART: Received %02x (%c) from serial at pos %-d", Drx, Drx, absReadPos);
    end
end

always @(posedge _RD) begin
    if (_MR) begin
        if (_RXF) begin
                $display("%t ", $time, "UART: _RD going high while _RXF not ready");
                $finish_and_return(1);
        end

        // only advance the read position at the END of the read otherwise _RXF goes high too early
        if (verbose) $display("%t ", $time, "UART: ADVANCING READ POS FROM %3d", absReadPos);
        absReadPos++;

        #T11 // -WR to _TXE inactive delay
        if (verbose) $display("%t ", $time, "UART: RX NOT READY");
        RX_READY=0; 

        #T12 // min inactity period
        if (verbose) $display("%t ", $time, "UART: RX INACTIVE PERIOD ENDS");
        RX_READY=1;
    end
end



initial 
    begin : file_block 
    $timeformat(-9, 0, "ns", 6); 

    for(int i=0; i<BUFFER_SIZE; i++) begin
        rxBuf[i] = i;
    end

    RX_READY=0;
    TX_READY=0;
    #50
    _MR=1;
    $display("%t UART: reset end",$time);
    #50

    // FIXME
    //absWritePos = 15; // next place to write into receive buffer

    TX_READY=1;
    RX_READY=1;
    #50

    if (1) begin
        $display("[%9t] ", $time, "opening uart.control");
        fControl = $fopenr("/tmp/uart.control"); 
        if (fControl == `NULL) // If error opening file 
        begin
                $error("[%9t] ", $time, "failed opening file");
                disable file_block; // Just quit 
        end

        $display("[%9t] ", $time, "opening uart.out");
        fOut = $fopen("/tmp/uart.out", "w+"); 
        if (fOut == `NULL) // If error opening file 
        begin
                $error("[%9t] ", $time, "failed opening file");
                disable file_block; // Just quit 
        end

        $display("[%9t] ", $time, "fifos open");

        while (fControl != `NULL)  
        begin
            c = $fgetc(fControl); 

            if (c != `EOF) 
            begin 
                    /* Check the first character for comment */ 
                    if (c == "/") // just skip
                    begin 
                        line="";
                        r = $fgets(line, fControl); 
                        str = strip(line);

                        $display("[%9t] ", $time, "/%s", str);
                    end

                    if (c == "r") // pass string back to simulatiom
                    begin
                        line="";
                        r = $fgets(line, fControl); 
                        str = strip(line);

                        if (verbose) $display("[%9t] ", $time, "RX: '%s' into ringpos=%3d abs=%3d, spaceAvailable=%1b", str, absWritePos%BUFFER_SIZE, absWritePos, spaceAvailable);

                        for (int p=0; p<str.len() && spaceAvailable; p++) begin
                            rxBuf[absWritePos%BUFFER_SIZE] = str[p];
                            absWritePos++;
                        end
                        if (! spaceAvailable)
                            $display("%t ", $time, "UART: RECEIVE BUFFER NOW FULL");

                        if (verbose) 
                            $display("%t ", $time, "UART: RECEIVE absWritePos %3d, absReadPos=%3d", absWritePos, absReadPos);
                    end
                    
                    if (c == "t") // wait for simulation to transmit N chars
                    begin
                        txLength=0;

                        line="";
                        r = $fgets(line, fControl);  // consumes the line ending and space chars 
                        r = $sscanf(line,"%d\n", txLength); 

                        if (verbose) $display("[%9t] ", $time, "TX: waiting for %1d chars", txLength);
                        tx_count = txLength;
                    end
                    
                    if (c == "#") // skil N ns
                    begin
                        tDelta=0;
                        line="";
                        r = $fgets(line, fControl);  // consumes the line ending and space chars 
                        r = $sscanf(line,"%d\n", tDelta); 

                        if (verbose) $display("[%9t] ", $time, "#%1d delay begin", tDelta);
                        #tDelta 

                        $display("[%9t] ", $time, "#%1d delay end", tDelta);
                    end

                    if (c == "q") // quit
                    begin
                        r = $fgets(line, fControl);  // consumes the line ending and space chars 
                        $display("[%9t] ", $time, "QUIT");
                        $finish;
                    end

                    if (c == "\n") // quit
                    begin
                        $display("[%9t] ", $time, "");
                    end

            end
/*            else
            begin
                $display("EOF");
                $finish;
            end // if not EOF 
 */       
        end // while
    end
end // initial

endmodule




