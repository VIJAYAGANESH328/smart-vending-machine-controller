`timescale 1ns/1ps
module tb_vending_machine;
  reg clk = 0, rst = 1, cancel = 0;
  reg [1:0] coin_in = 0, select = 0;
  wire dispense, change_valid;
  wire [1:0] item_out, state_out;
  wire [7:0] change_out, balance;
  integer passes = 0, fails = 0;

  localparam [1:0] IDLE = 0, COLLECT = 1, DISPENSE = 2, CHANGE = 3;
  localparam [1:0] C5 = 2'b01, C10 = 2'b10, C20 = 2'b11;
  localparam [1:0] A = 2'b01, B = 2'b10, C = 2'b11;

  vending_machine dut (.clk(clk), .rst(rst), .coin_in(coin_in), .select(select),
    .cancel(cancel), .dispense(dispense), .item_out(item_out),
    .change_out(change_out), .change_valid(change_valid),
    .balance(balance), .state_out(state_out));

  always #5 clk = ~clk;

  // Apply inputs for one clock, then look at the registered result.
  task tick(input [1:0] c, input [1:0] s, input can);
    begin
      @(negedge clk);
      coin_in = c; select = s; cancel = can;
      @(posedge clk); #1;
      coin_in = 0; select = 0; cancel = 0;
    end
  endtask

  task check(input ok, input [8*34-1:0] name);
    begin
      if (ok) passes = passes + 1;
      else begin
        fails = fails + 1;
        $display("FAIL: %0s (state=%0d bal=%0d disp=%b item=%0d chg=%0d t=%0t)",
                 name, state_out, balance, dispense, item_out, change_out, $time);
      end
    end
  endtask

  // Run the DISPENSE and CHANGE steps after a purchase and check them.
  task finish_sale(input [1:0] item, input [7:0] exp_change);
    begin
      check(state_out == DISPENSE && dispense && item_out == item, "dispense released item");
      tick(0, 0, 0);
      check(state_out == CHANGE && change_valid && change_out == exp_change, "change amount correct");
      tick(0, 0, 0);
      check(state_out == IDLE && balance == 0 && !dispense, "returned to IDLE");
    end
  endtask

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_vending_machine);
    $display("Smart Vending Machine Controller - self-checking test");
    repeat (2) @(posedge clk);
    #1 rst = 0;
    check(state_out == IDLE && balance == 0, "idle after reset");

    // 1. Exact payment: Rs 10 for item A.
    $display("Test 1: exact payment");
    tick(C10, 0, 0);
    check(state_out == COLLECT && balance == 10, "collect 10");
    tick(0, A, 0);
    finish_sale(A, 0);

    // 2. Overpayment: Rs 20 for item B (Rs 15) gives Rs 5 back.
    $display("Test 2: overpayment and change");
    tick(C20, 0, 0);
    tick(0, B, 0);
    finish_sale(B, 5);

    // 3. Insufficient balance, then add more coins.
    $display("Test 3: insufficient balance");
    tick(C5, 0, 0);
    tick(0, A, 0);
    check(state_out == COLLECT && !dispense, "no dispense with 5 for A");
    tick(C5, 0, 0);
    check(balance == 10, "balance 10 after second coin");
    tick(0, A, 0);
    finish_sale(A, 0);

    // 4. Cancel returns the full balance.
    $display("Test 4: cancel refund");
    tick(C10, 0, 0);
    tick(C5, 0, 0);
    tick(0, 0, 1);
    check(state_out == CHANGE && change_out == 15 && !dispense, "refund 15, no item");
    tick(0, 0, 0);
    check(state_out == IDLE && balance == 0, "idle after refund");

    // 5. Reset in the middle of a transaction.
    $display("Test 5: reset during transaction");
    tick(C20, 0, 0);
    @(negedge clk) rst = 1;
    @(posedge clk); #1 rst = 0;
    check(state_out == IDLE && balance == 0, "reset clears state");

    // 6. Item pressed with no money does nothing.
    $display("Test 6: select without coin");
    tick(0, C, 0);
    check(state_out == IDLE && !dispense, "no sale without coin");

    // 7. Three coins for item B, then item C with exact Rs 20.
    $display("Test 7: multiple coins");
    tick(C5, 0, 0); tick(C5, 0, 0); tick(C5, 0, 0);
    check(balance == 15, "balance 15 after three coins");
    tick(0, B, 0);
    finish_sale(B, 0);
    tick(C20, 0, 0);
    tick(0, C, 0);
    finish_sale(C, 0);

    // 8. Back-to-back sales with change.
    $display("Test 8: back-to-back sales");
    tick(C20, 0, 0); tick(0, A, 0); finish_sale(A, 10);
    tick(C10, 0, 0); tick(C10, 0, 0); tick(0, C, 0); finish_sale(C, 0);

    // 9. Coin has priority over select in the same clock.
    $display("Test 9: coin and select together");
    tick(C10, 0, 0);
    tick(C5, A, 0);
    check(state_out == COLLECT && balance == 15, "coin accepted first");
    tick(0, B, 0);
    finish_sale(B, 0);

    $display("PASS: %0d checks, FAIL: %0d checks", passes, fails);
    if (fails == 0) $display("ALL TESTS PASSED");
    else            $display("SOME TESTS FAILED");
    $finish;
  end
endmodule
