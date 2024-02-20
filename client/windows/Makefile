CC = g++
WIN_FLAGS = -D WIN -lws2_32 -ldnsapi -w
PROD_FLAGS = -Os
DEBUG_FLAGS = -g

production: build/logger
	strip -s -R .comment -R .gnu.version --strip-unneeded $^.exe
	
debug: build/logger_debug

build/logger: build/logger.o
	$(CC) $(PROD_FLAGS) -o $@ $^ $(WIN_FLAGS)
	
build/logger.o: logger.cpp
	$(CC) $(PROD_FLAGS) -o $@ -c $^ $(WIN_FLAGS)

build/logger_debug: build/logger_debug.o
	$(CC) $(DEBUG_FLAGS) -o $@ $^ $(WIN_FLAGS)

build/logger_debug.o: logger.cpp
	$(CC) $(DEBUG_FLAGS) -o $@ -c $^ $(WIN_FLAGS)