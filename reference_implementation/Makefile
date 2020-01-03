all: main.c
	gcc -g -std=c99 jpeg.c util.c main.c bit_packer.c -o jfpjc_c -Wall -lnetpbm -lm
#	gcc -g -std=c99 jpeg.c -o jfpjc_c -Wall -lnetpbm -lm

clean:
	rm jfpjc_c
