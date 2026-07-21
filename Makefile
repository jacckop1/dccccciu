SHELL := /bin/bash

.PHONY: all verify generate build clean

all: build

verify:
	python3 tools/verify_translations.py
	python3 tools/test_auto_language.py
	python3 tools/test_scoped_architecture.py

generate:
	python3 tools/generate_translations.py

build: verify generate
	chmod +x build.sh
	bash ./build.sh

clean:
	rm -rf build coverage-report.txt
