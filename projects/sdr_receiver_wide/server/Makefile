CFLAGS = -O3 -march=armv7-a -mtune=cortex-a9 -mfpu=neon -mfloat-abi=hard

all: sdr-receiver-wide gen

sdr-receiver-hpsdr: sdr-receiver-wide.c
	gcc $(CFLAGS) -o $@ $^ -lm -lpthread

gen: gen.c
	gcc $(CFLAGS) -o $@ $^ -lm

clean:
	rm -f sdr-receiver-wide gen
