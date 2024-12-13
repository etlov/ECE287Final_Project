This directory has the necessary modules for our Gaussian blur project.

There are 3 modules in this directory that are used to make this work.

- 1) vga_frame_drive- Manages the VGA display process which consists of frame buffering, pixel rendering, 
and blur effect which goes through a state machine that handles double buffering and dynamic image processing.

- 2) line_buffer - Efficiently tracks the neighboring pixel information for each pixel in the image, 
maintaining current and previous line buffers to support our implementation of Gaussian blur.

- 3) gaussian_blue_fsm - Efficiently tracks and provides neighboring pixel information for each pixel in 
the image, maintaining current and previous line buffers to support complex image processing algorithms like Gaussian blur.

These three modules work together to create a VGA display system with image processing capabilities.
