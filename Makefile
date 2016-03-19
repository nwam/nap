CC = gcc
CFLAGS = -ggdb -O0 -std=gnu11 -Wall -Werror
CURLC = `curl-config --cflags`
CURLL = `curl-config --libs`

all: nplogin clean

nplogin: nplogin.o
	$(CC) -o nplogin nplogin.o $(CFLAGS) $(CURLL)

nplogin.o: nplogin.c
	$(CC) -c nplogin.c $(CFLAGS) $(CURLC)

clean:
	rm -f *.o *.a
