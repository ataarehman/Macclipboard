.PHONY: build test app clean

build:
	swift build

test:
	./scripts/test.sh

app:
	./scripts/package-app.sh

clean:
	rm -rf .build dist
