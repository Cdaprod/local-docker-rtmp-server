VERSION_FILE=.version

build:
	docker build -t cdaprod/win-obs:dev .

version:
	./scripts/next-version.sh > $(VERSION_FILE)

tag:
	./scripts/next-version.sh --tag