`timescale 1ns / 1ps

module button (
    input clk,
    input in,

    output out
);

    localparam N = 64;

    reg [N-1:0] Q_reg, Q_next;
    wire w_debounce_out;
    reg [1:0] diff_reg, diff_next;


    // debounce circuit
    always @(*) begin
        Q_next = {Q_reg[N-2:0], in};  // left shift
    end


    always @(posedge clk) begin
        Q_reg    <= Q_next;  // 매 클럭마다 shift돼서 출력
        diff_reg <= diff_next;
    end


    assign w_debounce_out = &Q_reg;


    // dff edge-detector
    always @(*) begin
        diff_next[0] = w_debounce_out;
        diff_next[1] = diff_reg[0];
    end


    // output logic
    assign out = ~diff_reg[0] & diff_reg[1];

endmodule

