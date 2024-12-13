This directory has the necessary modules for our Gaussian blur project.

There are 3 modules in this directory that are used to make this work, and a project called vga_driver_to_frame_buf
given to us by Dr. Jamieson our professor for ECE287 at Miami University through Canvas. 

1) vga_frame_drive- Manages the VGA display process which consists of frame buffering, pixel rendering, 
and blur effect which goes through a state machine that handles double buffering and dynamic image processing.

2) line_buffer - Efficiently tracks the neighboring pixel information for each pixel in the image, 
maintaining current and previous line buffers to support our implementation of Gaussian blur.

3) gaussian_blur_fsm - Efficiently tracks and provides neighboring pixel information for each pixel in 
the image, maintaining current and previous line buffers to support complex image processing algorithms like Gaussian blur.

4) vga_driver_to_frame_buf - in this code, I show how you can write pixels to the frame buf.  The frame buf is
now encapsulated in a design and uses 3 memories.  You just write pixels into the memory as accessed on lines 205-207

These three modules work together, using this project given to us by Dr. Jamieson to implement our image processing onto a VGA display,
with a DE1-SoC board.
