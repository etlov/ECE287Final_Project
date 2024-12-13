module gaussian_blur_fsm (
    input clk,
    input rst,
    input [23:0] pixel_in,
    input [9:0] x,
    input [9:0] y,
    input valid_in,
    input [23:0] pixel_left,
    input [23:0] pixel_right,
    input [23:0] pixel_top,
    input [23:0] pixel_bottom,
    input [23:0] pixel_tl,
    input [23:0] pixel_tr,
    input [23:0] pixel_bl,
    input [23:0] pixel_br,
    
    output reg [23:0] pixel_out,
    output reg valid_out
);

// Just use the center and immediate neighbors first
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        pixel_out <= 24'h000000;
        valid_out <= 0;
    end else if (valid_in) begin
        // Simple average of center pixel and its immediate neighbors
        pixel_out[23:16] <= (pixel_in[23:16] + pixel_left[23:16] + pixel_right[23:16]) / 3; // Red
        pixel_out[15:8] <= (pixel_in[15:8] + pixel_left[15:8] + pixel_right[15:8]) / 3;     // Green
        pixel_out[7:0] <= (pixel_in[7:0] + pixel_left[7:0] + pixel_right[7:0]) / 3;         // Blue
        
        valid_out <= 1;
    end else begin
        valid_out <= 0;
    end
end

endmodule