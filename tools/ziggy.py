#!/usr/bin/env python3

# This tool just generates an unrolled version of the jpeg zigzag sequence.

# zigzag starts on [1, 0] and moves in the downwards direction
zigdir = -1;
zig_x = 1;
zig_y = 0;

print("X[0] = Y[0];")
for i in range(1, 64):
    zigidx = (zig_x + (8 * zig_y));
    print("X[%i] = Y[%i];"%(i, zigidx))

    # update zig coordinates
    # check and see if moving in the zig direction would put us out of bounds
    nx = zig_x + zigdir;
    ny = zig_y - zigdir;
    if ((nx < 0) and (ny > 7)):
        zig_x += 1;
        zigdir = -zigdir;
    elif ((nx < 0) and (zigdir == -1)):
        zig_y += 1;
        zigdir = -zigdir;
    elif ((ny < 0) and (zigdir == 1)):
        zig_x += 1;
        zigdir = -zigdir;
    elif ((nx > 7) and (zigdir == 1)):
        zig_y += 1;
        zigdir = -zigdir;
    elif ((ny > 7) and (zigdir == -1)):
        zig_x += 1;
        zigdir = -zigdir;
    else:
        zig_x = nx;
        zig_y = ny;


# you can copy and paste this inside a python interpreter in case you need that.
def ziggy():
    zig_x = 1
    zig_y = 0
    retval = [0]
    for i in range(1, 64):
        zigidx = (zig_x + (8 * zig_y));
        retval.append(zigidx)
        #print("X[%i] = Y[%i];"%(i, zigidx))
        # update zig coordinates
        # check and see if moving in the zig direction would put us out of bounds
        nx = zig_x + zigdir;
        ny = zig_y - zigdir;
        if ((nx < 0) and (ny > 7)):
            zig_x += 1;
            zigdir = -zigdir;
        elif ((nx < 0) and (zigdir == -1)):
            zig_y += 1;
            zigdir = -zigdir;
        elif ((ny < 0) and (zigdir == 1)):
            zig_x += 1;
            zigdir = -zigdir;
        elif ((nx > 7) and (zigdir == 1)):
            zig_y += 1;
            zigdir = -zigdir;
        elif ((ny > 7) and (zigdir == -1)):
            zig_x += 1;
            zigdir = -zigdir;
        else:
            zig_x = nx;
            zig_y = ny;
    return retval
