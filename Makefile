
dependencies: index.jl
	@kip $<
	@ln -snf ../.. $@/coiljl/server

test: dependencies
	@jest test.jl

.PHONY: test
