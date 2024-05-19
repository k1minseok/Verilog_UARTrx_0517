`timescale 1ns / 1ps

module top (
    input clk,
    input reset,
    input btn_tx_start1,
    input btn_tx_start2,

    output txd
);

    wire w_btn_tx_start1, w_btn_tx_start2;
    wire [7:0] w_rx_data;

    button U_BTN_Tx (
        .clk(clk),
        .in (btn_tx_start1),

        .out(w_btn_tx_start1)
    );

    button U_BTN_Tx2 (
        .clk(clk),
        .in (btn_tx_start2),

        .out(w_btn_tx_start2)
    );

    uart U_UART (
        .clk(clk),
        .reset(reset),
        .tx_start(w_btn_tx_start1),
        .tx_data(8'h41),  // 'A'

        // .tx(txd),
        .tx_done(),
        .rx_data(w_rx_data),
        .rx_done()
    );


    transmitter U_TxD (
        .clk(clk),
        .reset(reset),
        .tx_start(w_btn_tx_start2),
        .br_tick(w_br_tick),
        .tx_data(w_rx_data),

        .tx(txd),
        .tx_done()
    );

endmodule
