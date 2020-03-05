
JMCUJC_DIR=../../jmcujc

INCLUDES=
INCLUDES+= -I$(JMCUJC_DIR)

SRC=
SRC+= main.c
SRC+= util.c
SRC+= jmcujc.c
SRC+= jmcujc_image_util.c
SRC+= jmcujc_utils.c

VPATH+= $(JMCUJC_DIR)

CFLAGS = -O0
CFLAGS+= -g -std=c99 -Wall -Wno-unused-function
CFLAGS+= $(INCLUDES)

TARGET= jfpjc_c

all: $(SRC)
	gcc $(CFLAGS) $^ -o $(TARGET) -lnetpbm -lm

clean:
	rm $(TARGET)
