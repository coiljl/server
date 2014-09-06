
dependencies: dependencies.json
	@packin install --folder $@ --meta $<

test: dependencies
	@$</jest/bin/jest test

.PHONY: test
