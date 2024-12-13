module vga_frame_driver(

input clk,
input rst,
input [3:0] KEY,

output active_pixels, // is on when we're in the active draw space
output frame_done, // is on when we're done writing 640*480

// NOTE x and y that are passed out go greater than 640 for x and 480 for y as those signals need to be sent for hsync and vsync
output [9:0]x, // current x 
output [9:0]y, // current y - 10 bits = 1024 ... a little bit more than we need

//////////// VGA //////////
output		          		VGA_BLANK_N,
output		          		VGA_CLK,
output		          		VGA_HS,
output reg	     [7:0]		VGA_B,
output reg	     [7:0]		VGA_G,
output reg	     [7:0]		VGA_R,
output		          		VGA_SYNC_N,
output		          		VGA_VS,
output 				[23:0] debug_center,
output 				[23:0] debug_left,
output 				[23:0] debug_right,
output [7:0]     LEDR, 

/* access ports to the frame we draw from */
input [14:0] the_vga_draw_frame_write_mem_address,
input [23:0] the_vga_draw_frame_write_mem_data,
input the_vga_draw_frame_write_a_pixel
);


assign LEDR[2:0] = center_pixel[23:21];  // Show top 3 bits of red channel
assign LEDR[5:3] = neighbor_l[23:21];    // Show top 3 bits of left pixel
assign LEDR[7:6] = neighbor_r[23:22];    // Show top 2 bits of right pixel
/* MEMORIES -------------------------------- */
/* signals that will be combinationally swapped in each cycle - this is the double buffer */
reg [1:0] wr_id;
reg [15:0] write_buf_mem_address;
reg [23:0] write_buf_mem_data;
reg write_buf_mem_wren;
reg [23:0] read_buf_mem_q;
reg [15:0] read_buf_mem_address;

// Gaussian blur related signals
wire [23:0] blurred_pixel;
wire blur_valid_out;
wire [23:0] center_pixel;
// New individual neighbor wires instead of array
wire [23:0] neighbor_tl, neighbor_t, neighbor_tr;
wire [23:0] neighbor_l, neighbor_r;
wire [23:0] neighbor_bl, neighbor_b, neighbor_br;
wire buffer_valid;

/* MEMORY to STORE the framebuffers */
reg [15:0] frame_buf_mem_address0;
reg [23:0] frame_buf_mem_data0;
reg frame_buf_mem_wren0;
wire [23:0]frame_buf_mem_q0;

vga_frame vga_memory0(
    frame_buf_mem_address0,
    clk,
    frame_buf_mem_data0,
    frame_buf_mem_wren0,
    frame_buf_mem_q0);
    
reg [15:0] frame_buf_mem_address1;
reg [23:0] frame_buf_mem_data1;
reg frame_buf_mem_wren1;
wire [23:0]frame_buf_mem_q1;

vga_frame vga_memory1(
    frame_buf_mem_address1,
    clk,
    frame_buf_mem_data1,
    frame_buf_mem_wren1,
    frame_buf_mem_q1);

/* This is the frame that is written to and readfrom into the double buffering */
reg [15:0] the_vga_draw_frame_mem_address;
reg [23:0] the_vga_draw_frame_mem_data;
reg the_vga_draw_frame_mem_wren;
wire [23:0] the_vga_draw_frame_mem_q;

reg blur_enabled;
reg key1_prev;

vga_frame the_vga_draw_frame(
    .address(the_vga_draw_frame_mem_address),
    .clock(clk),
    .data(the_vga_draw_frame_mem_data),
    .wren(the_vga_draw_frame_mem_wren),
    .q(the_vga_draw_frame_mem_q)
);

// Line buffer instantiation
line_buffer line_buf_inst (
    .clk(clk),
    .rst(rst),
    .pixel_in(read_buf_mem_q),
    .pixel_addr(((y/PIXEL_VIRTUAL_SIZE) * VIRTUAL_PIXEL_WIDTH) + (x/PIXEL_VIRTUAL_SIZE)),
    .valid_in(active_pixels),
    .pixel_out(center_pixel),
    .neighbor_tl(neighbor_tl),
    .neighbor_t(neighbor_t),
    .neighbor_tr(neighbor_tr),
    .neighbor_l(neighbor_l),
    .neighbor_r(neighbor_r),
    .neighbor_bl(neighbor_bl),
    .neighbor_b(neighbor_b),
    .neighbor_br(neighbor_br),
    .valid_out(buffer_valid)
);

// Gaussian blur instantiation
gaussian_blur_fsm blur (
    .clk(clk),
    .rst(rst),
    .pixel_in(center_pixel),
    .x(x),
    .y(y),
    .valid_in(buffer_valid),
    .pixel_out(blurred_pixel),
    .valid_out(blur_valid_out),
    .pixel_left(neighbor_l),
    .pixel_right(neighbor_r),
    .pixel_top(neighbor_t),
    .pixel_bottom(neighbor_b),
    .pixel_tl(neighbor_tl),
    .pixel_tr(neighbor_tr),
    .pixel_bl(neighbor_bl),
    .pixel_br(neighbor_br)
);

/* ALWAYS block writes to the memory or otherwise is just being read into the framebuffer */
always @(*)
begin
    /* writing from external code */
    if (the_vga_draw_frame_write_a_pixel == 1'b1) 
    begin
        the_vga_draw_frame_mem_address = the_vga_draw_frame_write_mem_address;
        the_vga_draw_frame_mem_data = the_vga_draw_frame_write_mem_data;
        the_vga_draw_frame_mem_wren = 1'b1;
    end
    else
    begin
        /* just reading */
        the_vga_draw_frame_mem_address = (x/PIXEL_VIRTUAL_SIZE) * VIRTUAL_PIXEL_HEIGHT + (y/PIXEL_VIRTUAL_SIZE);
        the_vga_draw_frame_mem_data = 14'd0;
        the_vga_draw_frame_mem_wren = 1'b0;    
    end
end

reg [7:0]S;
reg [7:0]NS;

parameter 
    START             = 8'd0,
    W2M_DONE         = 8'd4,
    RFM_INIT_START     = 8'd5,
    RFM_INIT_WAIT     = 8'd6,
    RFM_DRAWING     = 8'd7,
    ERROR             = 8'hFF;

parameter MEMORY_SIZE = 16'd19200; // 160*120
parameter PIXEL_VIRTUAL_SIZE = 16'd4;

/* ACTUAL VGA RESOLUTION */
parameter VGA_WIDTH = 16'd640; 
parameter VGA_HEIGHT = 16'd480;

/* Our reduced RESOLUTION 160 by 120 */
parameter VIRTUAL_PIXEL_WIDTH = VGA_WIDTH/PIXEL_VIRTUAL_SIZE; // 160
parameter VIRTUAL_PIXEL_HEIGHT = VGA_HEIGHT/PIXEL_VIRTUAL_SIZE; // 120

vga_driver the_vga(
    .clk(clk),
    .rst(rst),
    .vga_clk(VGA_CLK),
    .hsync(VGA_HS),
    .vsync(VGA_VS),
    .active_pixels(active_pixels),
    .frame_done(frame_done),
    .xPixel(x),
    .yPixel(y),
    .VGA_BLANK_N(VGA_BLANK_N),
    .VGA_SYNC_N(VGA_SYNC_N)
);

// Modified VGA output logic to use blurred pixels
always @(*) begin
    if (S == RFM_INIT_WAIT || S == RFM_INIT_START || S == RFM_DRAWING) begin
        if (!KEY[3] && blur_valid_out)  // Only use blurred pixel when KEY[3] pressed and blur is valid
            {VGA_R, VGA_G, VGA_B} = blurred_pixel;
        else
            {VGA_R, VGA_G, VGA_B} = read_buf_mem_q;
    end else
        {VGA_R, VGA_G, VGA_B} = 24'hFFFFFF;
end

/* Calculate NS */
always @(*)
    case (S)
        START: NS = W2M_DONE;
        W2M_DONE: 
            if (frame_done == 1'b1)
                NS = RFM_INIT_START;
            else
                NS = W2M_DONE;
    
        RFM_INIT_START: NS = RFM_INIT_WAIT;
        RFM_INIT_WAIT: 
            if (frame_done == 1'b0)
                NS = RFM_DRAWING;
            else    
                NS = RFM_INIT_WAIT;
        RFM_DRAWING:
            if (frame_done == 1'b1)
                NS = RFM_INIT_START;
            else
                NS = RFM_DRAWING;
        default:    NS = ERROR;
    endcase

always @(posedge clk or negedge rst)
begin
    if (rst == 1'b0)
    begin
            S <= START;
    end
    else
    begin
            S <= NS;
    end
end

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        blur_enabled <= 1'b0;
        key1_prev <= 1'b1;  // Active low button
    end else begin
        // Store previous key state
        key1_prev <= KEY[3];
        
        // Detect falling edge of KEY[3] (button press)
        if (key1_prev && !KEY[3]) begin
            blur_enabled <= !blur_enabled;  // Toggle blur on/off
        end
    end
end


parameter MEM_INIT_WRITE = 2'd0,
          MEM_M0_READ_M1_WRITE = 2'd1,
          MEM_M0_WRITE_M1_READ = 2'd2,
          MEM_ERROR = 2'd3;

always @(posedge clk or negedge rst)
begin
    if (rst == 1'b0)
    begin
        write_buf_mem_address <= 14'd0;
        write_buf_mem_data <= 24'd0;
        write_buf_mem_wren <= 1'd0;
        wr_id <= MEM_INIT_WRITE;
    end
    else
    begin
        case (S)
            START:
            begin
                write_buf_mem_address <= 14'd0;
                write_buf_mem_data <= 24'd0;
                write_buf_mem_wren <= 1'd0;
                wr_id <= MEM_INIT_WRITE;
            end
            W2M_DONE: write_buf_mem_wren <= 1'd0;
            
            RFM_INIT_START: 
            begin
                write_buf_mem_wren <= 1'd0;
                
                if (wr_id == MEM_INIT_WRITE)
                    wr_id <= MEM_M0_READ_M1_WRITE;
                else if (wr_id == MEM_M0_READ_M1_WRITE)
                    wr_id <= MEM_M0_WRITE_M1_READ;
                else
                    wr_id <= MEM_M0_READ_M1_WRITE;
                                
                if (y < VGA_HEIGHT-1 && x < VGA_WIDTH-1)
                    read_buf_mem_address <= (x/PIXEL_VIRTUAL_SIZE) * VIRTUAL_PIXEL_HEIGHT + (y/PIXEL_VIRTUAL_SIZE);
            end
            RFM_INIT_WAIT:
            begin
                if (y < VGA_HEIGHT-1 && x < VGA_WIDTH-1)
                    read_buf_mem_address <= (x/PIXEL_VIRTUAL_SIZE) * VIRTUAL_PIXEL_HEIGHT + (y/PIXEL_VIRTUAL_SIZE);
            end
            RFM_DRAWING:
            begin        
                if (y < VGA_HEIGHT-1 && x < VGA_WIDTH-1)
                    read_buf_mem_address <= (x/PIXEL_VIRTUAL_SIZE) * VIRTUAL_PIXEL_HEIGHT + (y/PIXEL_VIRTUAL_SIZE);
                
                write_buf_mem_address <= (x/PIXEL_VIRTUAL_SIZE) * VIRTUAL_PIXEL_HEIGHT + (y/PIXEL_VIRTUAL_SIZE);
                write_buf_mem_data <= the_vga_draw_frame_mem_q;
                write_buf_mem_wren <= 1'b1;
            end    
        endcase
    end
end

/* Double buffer output swapping logic */
always @(*)
begin
    if (wr_id == MEM_INIT_WRITE)
    begin
        frame_buf_mem_address0 = write_buf_mem_address;
        frame_buf_mem_data0 = write_buf_mem_data;
        frame_buf_mem_wren0 = write_buf_mem_wren;
        frame_buf_mem_address1 = write_buf_mem_address;
        frame_buf_mem_data1 = write_buf_mem_data;
        frame_buf_mem_wren1 = write_buf_mem_wren;
        read_buf_mem_q = frame_buf_mem_q1;
    end
    else if (wr_id == MEM_M0_WRITE_M1_READ)
    begin
        frame_buf_mem_address0 = write_buf_mem_address;
        frame_buf_mem_data0 = write_buf_mem_data;
        frame_buf_mem_wren0 = write_buf_mem_wren;
        frame_buf_mem_address1 = read_buf_mem_address;
        frame_buf_mem_data1 = 24'd0;
        frame_buf_mem_wren1 = 1'b0;
        read_buf_mem_q = frame_buf_mem_q1;
    end
    else
    begin
        frame_buf_mem_address0 = read_buf_mem_address;
        frame_buf_mem_data0 = 24'd0;
        frame_buf_mem_wren0 = 1'b0;
        read_buf_mem_q = frame_buf_mem_q0;
        frame_buf_mem_address1 = write_buf_mem_address;
        frame_buf_mem_data1 = write_buf_mem_data;
        frame_buf_mem_wren1 = write_buf_mem_wren;
    end
end


endmodule