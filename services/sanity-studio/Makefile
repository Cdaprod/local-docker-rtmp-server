ARCH := $(shell uname -m)
PLATFORM := $(if $(filter $(ARCH),arm64 aarch64),linux/arm64,linux/amd64)

.PHONY: docker-build
docker-build:
	docker buildx build \
		--platform $(PLATFORM) \
		--file Dockerfile \
		--tag cdaprod/$(notdir $(CURDIR)):dev \
		--load \
		.

.PHONY: sanity-dev
sanity-dev:
	docker-compose -f services/sanity-studio/docker-compose.sanity-studio.yaml up --build