class fifo_crtl_packet;
    
    // set up packet variables for randomizable signals
    rand    bit                         [15:0]                      data[];
    rand    bit                         [9:0]                       burst_length;

    // set up any process control variables (like delay or flags indicating current states)
    //

    // add up variable constraints
    constraint          data_burst_length {
        burst_length  inside {[0:16]};
        burst_length  % 2 == 0;
    }

    constraint          data_property  {
        burst_length == data.size();
        solve burst_length before data.size();
    }

    constraint          data_value      {
        foreach(data[i]) {
            data[i] > 0;
            data[i] < 1024;
        }
    }

    // implement methods for any instant value generation or check or display.
    function    void        display_random_values();
            $display("The randomized value of burst length is: \t %d", burst_length);
            $display("The randomized value of data is: \t %p", data);        
    endfunction

endclass