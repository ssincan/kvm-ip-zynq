module memory_model (
    input clk,
    input [31:0] waddr0,
    input [63:0] wdata0,
    input wen0,
    input [31:0] waddr1,
    input [63:0] wdata1,
    input wen1,
    input [31:0] waddr2,
    input [63:0] wdata2,
    input wen2,
    input [31:0] waddr3,
    input [63:0] wdata3,
    input wen3,
    input [31:0] raddr,
    output reg [63:0] rdata
);

    reg [63:0] mem [integer];

    always @(posedge clk) begin
        if(wen0)
            mem[waddr0] = wdata0;
        if(wen1)
            mem[waddr1] = wdata1;
        if(wen2)
            mem[waddr2] = wdata2;
        if(wen3)
            mem[waddr3] = wdata3;
        if(mem.exists(raddr))
            rdata = mem[raddr];
        else
            rdata = {64{1'bx}};
    end

endmodule