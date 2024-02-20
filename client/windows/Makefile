CC = g++
CFLAGS = -D WIN -lws2_32 -ldnsapi -w

build/logger: build/logger.o
	$(CC) -o $@ $^ $(CFLAGS)

build/logger.o: logger.cpp
	$(CC) -o $@ -c $^ $(CFLAGS)