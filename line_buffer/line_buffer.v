module line_buffer (
    input clk,
    input rst,
    input [23:0] pixel_in,
    input [14:0] pixel_addr,
    input valid_in,
    
    output reg [23:0] pixel_out,
    output reg [23:0] neighbor_tl,
    output reg [23:0] neighbor_t,
    output reg [23:0] neighbor_tr,
    output reg [23:0] neighbor_l,
    output reg [23:0] neighbor_r,
    output reg [23:0] neighbor_bl,
    output reg [23:0] neighbor_b,
    output reg [23:0] neighbor_br,
    output reg valid_out
);

// Define two complete line buffers
reg [23:0] line1 [0:159];  // Current line
reg [23:0] prev_line [0:159];  // Previous line
reg [7:0] x_pos;
reg [6:0] y_pos;
reg [23:0] last_pixel;

// Calculate position
always @(*) begin
    x_pos = pixel_addr % 160;
    y_pos = pixel_addr / 160;
end

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        valid_out <= 0;
        pixel_out <= 0;
        last_pixel <= 0;
        // Clear neighbor outputs
        neighbor_tl <= 0;
        neighbor_t <= 0;
        neighbor_tr <= 0;
        neighbor_l <= 0;
        neighbor_r <= 0;
        neighbor_bl <= 0;
        neighbor_b <= 0;
        neighbor_br <= 0;
    end else if (valid_in) begin
        // Store current pixel
        line1[x_pos] <= pixel_in;
        
        // At the end of each line, shift current line to previous line
        if (x_pos == 159) begin
            integer i;
            for (i = 0; i < 160; i = i + 1) begin
                prev_line[i] <= line1[i];
            end
        end
        
        // Set current pixel
        pixel_out <= pixel_in;
        last_pixel <= pixel_out;
        
        // Assign neighbors based on position
        if (x_pos == 0) begin
            // Left edge
            neighbor_l <= pixel_in;
            neighbor_tl <= (y_pos == 0) ? pixel_in : prev_line[0];
            neighbor_bl <= pixel_in;
        end else begin
            neighbor_l <= last_pixel;
            neighbor_tl <= (y_pos == 0) ? pixel_in : prev_line[x_pos-1];
            neighbor_bl <= line1[x_pos-1];
        end
        
        if (x_pos == 159) begin
            // Right edge
            neighbor_r <= pixel_in;
            neighbor_tr <= (y_pos == 0) ? pixel_in : prev_line[159];
            neighbor_br <= pixel_in;
        end else begin
            neighbor_r <= line1[x_pos+1];
            neighbor_tr <= (y_pos == 0) ? pixel_in : prev_line[x_pos+1];
            neighbor_br <= line1[x_pos+1];
        end
        
        // Top and bottom neighbors
        neighbor_t <= (y_pos == 0) ? pixel_in : prev_line[x_pos];
        neighbor_b <= (y_pos == 119) ? pixel_in : line1[x_pos];
        
        valid_out <= 1;
    end else begin
        valid_out <= 0;
    end
end

endmodule
