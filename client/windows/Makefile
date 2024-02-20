CC = g++
WIN_FLAGS = -D WIN -lws2_32 -ldnsapi -w
PROD_FLAGS = -Os -fvisibility=hidden -fvisibility-inlines-hidden -ffunction-sections -fdata-sections
DEBUG_FLAGS = -g

ifndef domain
$(error domain is not set)
endif

production: build/logger
	strip -s -R .comment -R .gnu.version --strip-unneeded $<.exe
	
debug: build/logger_debug

build/logger: build/logger.o
	$(CC) -DDOMAIN=\"$(domain)\" $(PROD_FLAGS) -o $@ $^ $(WIN_FLAGS)
	
build/logger.o: logger.cpp
	$(CC) -DDOMAIN=\"$(domain)\" $(PROD_FLAGS) -o $@ -c $^ $(WIN_FLAGS)

build/logger_debug: build/logger_debug.o
	$(CC) -DDOMAIN=\"$(domain)\" $(DEBUG_FLAGS) -o $@ $^ $(WIN_FLAGS)

build/logger_debug.o: logger.cpp domain_check
	$(CC) -DDOMAIN=\"$(domain)\" $(DEBUG_FLAGS) -o $@ -c $^ $(WIN_FLAGS)