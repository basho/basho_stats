.PHONY: compile rel cover test dialyzer eqc
REBAR=./rebar3

compile:
	$(REBAR) compile

clean:
	$(REBAR) clean

cover: test
	$(REBAR) cover

test: compile
	$(REBAR) as test do eunit

dialyzer:
	$(REBAR) dialyzer

xref:
	$(REBAR) xref

# As test, because the TEST macro is used
eqc:
	$(REBAR) as test eqc

check: test dialyzer xref
