CFLAGS = -O3 -march=armv7-a -mtune=cortex-a9 -mfpu=neon -mfloat-abi=hard -D_GNU_SOURCE

all: sdr-receiver-wide

sdr-receiver-hpsdr: sdr-receiver-wide.c
	gcc $(CFLAGS) -o $@ $^ -lm -lpthread

clean:
	rm -f sdr-receiver-wide
