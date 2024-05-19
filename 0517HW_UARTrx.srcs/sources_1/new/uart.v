`timescale 1ns / 1ps

module uart (
    input clk,
    input reset,
    input tx_start,
    input [7:0] tx_data,

    // output tx,
    output tx_done,
    output [7:0] rx_data,
    output rx_done
);

    wire w_br_tick;
    wire w_tx;

    baudrate_generator #(
        .HERZ(9600)
    ) U_BR_Gen (
        .clk  (clk),
        .reset(reset),

        .br_tick(w_br_tick)
    );


    transmitter U_TxD (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .br_tick(w_br_tick),
        .tx_data(tx_data),

        .tx(w_tx),
        .tx_done(tx_done)
    );


    receiver U_RxD (
        .clk(clk),
        .reset(reset),
        .br_tick(w_br_tick),
        .rx(w_tx),

        .rx_data(rx_data),
        .rx_done(rx_done)
    );

endmodule


module baudrate_generator #(
    parameter HERZ = 9600
) (
    input clk,
    input reset,

    output br_tick
);

    // reg [$clog2(100_000_000/9600)-1:0] counter_reg, counter_next;
    reg [$clog2(100_000_000/HERZ)-1:0] counter_reg, counter_next;
    reg tick_reg, tick_next;

    assign br_tick = tick_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            tick_reg <= 1'b0;
        end else begin
            counter_reg <= counter_next;
            tick_reg <= tick_next;
        end
    end

    always @(*) begin
        counter_next = counter_reg;
        // if (counter_reg == 100_000_000 / 9600 - 1) begin  // baudrate 9600Hz
        if (counter_reg == 100_000_000 / HERZ - 1) begin
            counter_next = 0;
            tick_next = 1'b1;
        end else begin
            counter_next = counter_reg + 1;
            tick_next = 1'b0;
        end
    end
endmodule


module transmitter (
    input clk,
    input reset,
    input tx_start,
    input br_tick,
    input [7:0] tx_data,

    output tx,
    output tx_done
);

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [7:0] tx_data_reg, tx_data_next;
    reg [1:0] state, state_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg tx_reg, tx_next, tx_done_reg, tx_done_next;


    // state rigister
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state <= IDLE;
            tx_data_reg <= 8'b0;
            bit_cnt_reg <= 3'd0;
            tx_reg <= 1'b1;
            tx_done_reg <= 1'b0;
        end else begin
            state <= state_next;
            tx_data_reg <= tx_data_next;
            bit_cnt_reg <= bit_cnt_next;
            tx_reg <= tx_next;
            tx_done_reg <= tx_done_next;
        end
    end


    // next state logic
    always @(*) begin
        state_next = state;
        tx_done_next = tx_done_reg;
        tx_data_next = tx_data_reg;
        tx_next = tx_reg;
        bit_cnt_next = bit_cnt_reg;

        case (state)
            IDLE: begin
                tx_next = 1'b1;
                tx_done_next = 1'b0;
                tx_data_next = 8'b0;
                if (tx_start) begin
                    tx_data_next = tx_data;
                    bit_cnt_next = 0;
                    state_next   = START;
                end
            end

            START: begin
                tx_next = 1'b0;
                if (br_tick) state_next = DATA;
            end

            DATA: begin
                tx_next = tx_data_reg[0];
                if (br_tick) begin
                    if (bit_cnt_reg == 7) begin
                        //tx_next = 1'b0;
                        state_next = STOP;
                    end else begin
                        bit_cnt_next = bit_cnt_reg + 1;
                        tx_data_next = {1'b0, tx_data_reg[7:1]};
                        // right shift register(bit right shift)
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;
                if (br_tick) begin
                    state_next   = IDLE;
                    tx_done_next = 1'b1;
                end
            end

        endcase

    end


    // output logic
    assign tx = tx_reg;
    assign tx_done = tx_done_reg;

endmodule


module receiver (
    input clk,
    input reset,
    input br_tick,
    input rx,

    output [7:0] rx_data,
    output rx_done
);

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [1:0] state, state_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [7:0] rx_data_reg, rx_data_next, rx_cmplt_data, rx_cmplt_data_next;
    // reg rx_reg, rx_next;
    reg rx_done_reg, rx_done_next;


    // state register
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state <= IDLE;
            bit_cnt_reg <= 3'b0;
            rx_done_reg <= 1'b0;
            rx_data_reg <= 8'b0;
            rx_cmplt_data <= 8'b0;
            // rx_reg <= 1'b0;
        end else begin
            state <= state_next;
            bit_cnt_reg <= bit_cnt_next;
            rx_done_reg <= rx_done_next;
            rx_data_reg <= rx_data_next;
            rx_cmplt_data <= rx_cmplt_data_next;
            // rx_reg <= rx_next;
        end
    end


    // next state combinational logic
    always @(*) begin
        state_next = state;
        bit_cnt_next = bit_cnt_reg;
        rx_data_next = rx_data_reg;
        rx_done_next = rx_done_reg;
        rx_cmplt_data_next = rx_cmplt_data;

        case (state)
            IDLE: begin
                rx_data_next = 8'b0;
                rx_done_next = 1'b0;
                rx_cmplt_data_next = 8'b0;
                if (rx == 1'b0) begin
                    bit_cnt_next = 3'b0;
                    state_next   = START;
                end
            end

            START: begin
                if (br_tick) begin
                    state_next = DATA;
                end
            end

            DATA: begin
                if (br_tick) begin
                    rx_data_next = {rx, rx_data_reg[7:1]};
                    if (bit_cnt_next == 7) begin
                        state_next = STOP;
                        rx_cmplt_data_next = {rx, rx_data_reg[7:1]};
                    end else begin
                        bit_cnt_next = bit_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                if (br_tick) begin
                    state_next   = IDLE;
                    rx_done_next = 1'b1;
                end
            end

        endcase

    end


    // output combinational logic
    assign rx_data = rx_cmplt_data;
    assign rx_done = rx_done_reg;

endmodule
