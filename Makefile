
dependencies: dependencies.json
	@packin install --folder $@ --meta $<
	@ln -snf .. $@/server

test: dependencies
	@$</jest/bin/jest test

.PHONY: test
