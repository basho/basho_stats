include tools.mk

all: compile test

compile:
	@./rebar compile

clean:
	./rebar clean
