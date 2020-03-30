`include "../lib/assertion.v"
`include "./hct74245.v"
`timescale 1ns/100ps

module tb();

      tri [7:0]A;
      tri [7:0]B;

      logic [7:0] Vb=8'b00000000;
      logic [7:0] Va=8'b11111111;

      logic dir;
      logic nOEX;
      logic nOEY=1;

      assign B=Vb;
      assign A=Va;

      hct74245 #(.LOG(1), .NAME("BUFX")) buf245X(.A, .B, .dir, .nOE(nOEX));

        // Only used in Mux test
      wire [7:0] Ay = 8'b11111111;
      hct74245 #(.LOG(1), .NAME("BUFY")) buf245Y(.A(Ay), .B, .dir(1'b1), .nOE(nOEY));

    always @*
        $display($time, " => dir=%1b", dir, " nOEX=%1b", nOEX, " Astim=%8b", Va, " Bstim=%8b ", Vb, " A=%8b ", A," B=%8b ", B);
     
    initial begin
      
      Va=8'bxxxxxxxx;
      Vb=8'bxxxxxxxx;
      dir <= 1; // a->b
      nOEX <= 1;
      #30
      `equals(A , 8'bxxxxxxxx, "OE disable");
      `equals(B , 8'bxxxxxxxx, "OE disable");
      ////////////////////////////////

      Va=8'bzzzzzzzz;
      Vb=8'bzzzzzzzz;

      dir <= 1; // a->b
      nOEX <= 1;
      #30
      `equals(A , 8'bzzzzzzzz, "OE disable A->B");
      `equals(B , 8'bzzzzzzzz, "OE disable A->B");

      dir <= 0; // b->a
      nOEX <= 1;
      #30
      `equals(A , 8'bzzzzzzzz, "OE disable A->B");
      `equals(B , 8'bzzzzzzzz, "OE disable A->B");

      ////////////////////////////////

      Va=8'b11111111;
      Vb=8'b11111111;
      #30
       `equals(A , 8'b11111111, "OE disable - 1");
       `equals(B , 8'b11111111, "OE disable - 1");

      Va=8'b00000000;
      Vb=8'b00000000;
      #30
       `equals(A , 8'b00000000, "OE disable - 0");
       `equals(B , 8'b00000000, "OE disable - 0");
      
      ////////////////////////////////

      dir <= 0; // b->a
      nOEX <= 0;
      Va=8'bzzzzzzzz;
      Vb=8'b11111111;
      #30
       `equals(A , 8'b11111111, "OE B->A 1's");
       `equals(B , 8'b11111111, "OE B->A 1's");
      
      dir <= 0; // b->a
      nOEX <= 0;
      Va=8'bzzzzzzzz;
      Vb=8'b00000000;
      #30
       `equals(A , 8'b00000000, "OE B->A 0's");
       `equals(B , 8'b00000000, "OE B->A 0's");

      ////////////////////////////////

      dir <= 1; // a->b
      nOEX <= 0;
      Va=8'b00000000;
      Vb=8'bzzzzzzzz;
      #30
       `equals(A , 8'b00000000, "OE A->B 0's");
       `equals(B , 8'b00000000, "OE A->B 0's");
      
      dir <= 1; // a->b
      nOEX <= 0;
      Va=8'b11111111;
      Vb=8'bzzzzzzzz;
      #30
       `equals(A , 8'b11111111, "OE A->B 1's");
       `equals(B , 8'b11111111, "OE A->B 1's");

      ////////////////////////////////

    $display("conflict tests - output already asserted by other device");

      dir <= 1; // a->b
      nOEX <= 0;
      Va=8'b00000000;
      Vb=8'b1111111z;
      #30
       `equals(A , 8'b00000000, "OE A->B 0's");
       `equals(B , 8'bxxxxxxx0, "OE A->B 1 conflicted's");
      
      #30
      
      dir <= 1; // a->b
      nOEX <= 0;
      Va=8'b11111111;
      Vb=8'b0000000z;
      #30
       `equals(A , 8'b11111111, "OE A->B 1's");
       `equals(B , 8'bxxxxxxx1, "OE A->B 0 conflicted's");
      
      ////////////////////////////////
      dir <= 0; // b-a
      nOEX <= 0;
      Va=8'b1111111z;
      Vb=8'b00000000;
      #30
       `equals(A , 8'bxxxxxxx0, "OE B->A 1 conflicted's");
       `equals(B , 8'b00000000, "OE B->A 0's");
      
      dir <= 0; // b->a
      nOEX <= 0;
      Va=8'b0000000z;
      Vb=8'b11111111;
      #30
       `equals(A , 8'bxxxxxxx1, "OE B->A 1 conflicted's");
       `equals(B , 8'b11111111, "OE B->A 0's");
      
    $display("mux tests - switching to A->B with no driver");
      Va=8'b10101010;
      Vb=8'bzzzzzzzz;
      dir <= 1; // a->b
      nOEX <= 1;
      nOEY <= 1;
      #30
       `equals(B , 8'bzzzzzzzz, "OE A->B X driving");

    $display("muxed out - X driving");

      nOEX <= 0;
      nOEY <= 1;
      #30
       `equals(B , 8'b10101010, "OE A->B X driving");

    $display("muxed out - Y driving");

      nOEX <= 1;
      nOEY <= 0;
      #30
      `equals(B , 8'b11111111, "OE A->B Y driving");
    end

endmodule : tb

