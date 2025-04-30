# =============================================================================
# Enhanced Docker RTMP Server Makefile – Subcommand Style Without Hyphens
# =============================================================================

SHELL := /bin/bash
.SHELLFLAGS := -e -c
.ONESHELL:

# Project information
PROJECT_NAME ?= $(notdir $(CURDIR))
COMPOSE      ?= docker-compose
COMPOSE_CMD  = $(COMPOSE) -p $(PROJECT_NAME)

# Files and paths
COMPOSE_FILE  ?= docker-compose.yaml
OVERRIDE_FILE ?= docker-compose.override.yaml

# Conditionally include the override file if it exists
COMPOSE_FILES := -f $(COMPOSE_FILE)
ifeq ($(shell test -f $(OVERRIDE_FILE) && echo yes),yes)
	COMPOSE_FILES += -f $(OVERRIDE_FILE)
endif

# All Dockerfiles used across services
DOCKERFILES = \
  pi-obs-container/Dockerfile.arm64 \
  rtmp-server/Dockerfile \
  metadata-service/Dockerfile \
  services/nikon-control/Dockerfile \
  services/rtmp-watcher/Dockerfile \
  services/videos-relay/Dockerfile \
  infra/Dockerfile.infra-node \
  src/dockerfiles/obs-runtime-builder/Dockerfile

# Enable colors
BOLD    = \033[1m
RED     = \033[31m
GREEN   = \033[32m
YELLOW  = \033[33m
BLUE    = \033[34m
MAGENTA = \033[35m
CYAN    = \033[36m
RESET   = \033[0m

# --------------------------------------------------
# Versioning and Image Information
# --------------------------------------------------
VERSION      := $(shell git describe --tags --always)
ARCH         := $(shell uname -m)
REGISTRY     := ghcr.io
OWNER        := cdaprod
TAG_SUFFIX   := $(VERSION)-$(ARCH)

# --------------------------------------------------
# Extract the service name from the second word of make goals
# (This hack forces the second positional parameter to be stored in SERVICE.)
SERVICE := $(word 2, $(MAKECMDGOALS))

# Prevent the second word from being treated as a separate target.
%:
	@:

# -----------------------------------------------------------------------------
# Help Target
# -----------------------------------------------------------------------------
.PHONY: help
help: ## Display this help text
	@printf "$(BOLD)Usage:$(RESET)\n"
	@printf "  make <target> <service>\n\n"
	@printf "$(BOLD)Available targets:$(RESET)\n"
	@echo "  up                 Start all services"
	@echo "  down               Stop all services"
	@echo "  restart            Restart all services"
	@echo "  status             Show status of all services"
	@echo "  clean              Stop and remove all containers, networks, and volumes"
	@echo "  build              Build all services"
	@echo "  rebuild            Rebuild all services and restart"
	@echo "  prune              Remove all unused Docker resources"
	@echo "  rebuild-images     Force rebuild all project images"
	@echo "  inspect            Inspect running containers"
	@echo "  check-env          Verify environment configuration"
	@echo "  lint               Lint Dockerfiles for best practices"
	@echo ""
	@echo "  logs <service>     Show logs for a given service"
	@echo "  enter <service>    Open a shell in a given service container"
	@echo "  push <service>     Tag (automatically) and push the image for a given service"
	@echo ""
	@echo "Example:"
	@echo "  make logs obs"
	@echo "  make enter metadata-service"
	@echo "  make push obs"

# -----------------------------------------------------------------------------
# Main Docker Compose Commands
# -----------------------------------------------------------------------------
.PHONY: up down restart status clean build rebuild

up: ## Start all services (build if needed)
	@printf "$(BOLD)$(GREEN)Starting services for $(PROJECT_NAME)...$(RESET)\n"
	$(COMPOSE_CMD) down && $(COMPOSE_CMD) $(COMPOSE_FILES) up -d --build
	@printf "$(BOLD)$(GREEN)Services started.$(RESET)\n"

down: ## Stop all services
	@printf "$(BOLD)$(YELLOW)Stopping services for $(PROJECT_NAME)...$(RESET)\n"
	$(COMPOSE_CMD) down
	@printf "$(BOLD)$(GREEN)Services stopped.$(RESET)\n"

restart: ## Restart all services
	@printf "$(BOLD)$(YELLOW)Restarting services for $(PROJECT_NAME)...$(RESET)\n"
	$(MAKE) down
	$(MAKE) up
	@printf "$(BOLD)$(GREEN)Services restarted.$(RESET)\n"

status: ## Show status of all services
	@printf "$(BOLD)$(BLUE)Status of services for $(PROJECT_NAME):$(RESET)\n"
	$(COMPOSE_CMD) ps

clean: ## Stop and remove all containers, networks, and volumes
	@printf "$(BOLD)$(RED)Cleaning up $(PROJECT_NAME)...$(RESET)\n"
	$(COMPOSE_CMD) down -v --remove-orphans
	@printf "$(BOLD)$(GREEN)Cleanup complete.$(RESET)\n"

build: ## Build all services
	@printf "$(BOLD)$(BLUE)Building services for $(PROJECT_NAME)...$(RESET)\n"
	$(COMPOSE_CMD) $(COMPOSE_FILES) build -d
	@printf "$(BOLD)$(GREEN)Build complete.$(RESET)\n"

rebuild: ## Rebuild all services and restart
	@printf "$(BOLD)$(YELLOW)Rebuilding services for $(PROJECT_NAME)...$(RESET)\n"
	$(MAKE) clean
	$(MAKE) build
	$(MAKE) up
	@printf "$(BOLD)$(GREEN)Rebuild complete.$(RESET)\n"

# -----------------------------------------------------------------------------
# Docker Management Commands
# -----------------------------------------------------------------------------
.PHONY: prune rebuild-images inspect check-env lint

prune: ## Remove all unused Docker resources
	@printf "$(BOLD)$(RED)Pruning Docker system...$(RESET)\n"
	@read -p "$(BOLD)$(RED)WARNING: This will remove all unused Docker resources. Continue? [y/N] $(RESET)" confirm; \
	[[ $$confirm =~ ^[yY]$$ ]] || exit 1; \
	docker system prune -af --volumes; \
	printf "$(BOLD)$(GREEN)Docker system pruned.$(RESET)\n"

rebuild-images: ## Force rebuild all project images
	@printf "$(BOLD)$(YELLOW)Rebuilding all images for $(PROJECT_NAME)...$(RESET)\n"
	-docker rmi -f $$(docker images "$(OWNER)/*" -q) 2>/dev/null || true
	$(MAKE) build
	@printf "$(BOLD)$(GREEN)Images rebuilt.$(RESET)\n"

inspect: ## Inspect running containers
	@printf "$(BOLD)$(BLUE)Inspecting running containers for $(PROJECT_NAME):$(RESET)\n"
	@for container in $$($(COMPOSE_CMD) ps -q); do \
		if [ -n "$$container" ]; then \
			echo "$(BOLD)$(CYAN)Container: $$container$(RESET)"; \
			docker inspect --format='$(BOLD)Image:$(RESET) {{.Config.Image}}' $$container; \
			docker inspect --format='$(BOLD)State:$(RESET) {{.State.Status}}' $$container; \
			docker inspect --format='$(BOLD)Mounts:$(RESET) {{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' $$container; \
			echo; \
		fi; \
	done

check-env: ## Verify environment configuration
	@printf "$(BOLD)$(BLUE)Checking environment...$(RESET)\n"
	@echo "Docker version: $$(docker --version)"
	@echo "Docker Compose version: $$($(COMPOSE) --version)"
	@echo "Project name: $(PROJECT_NAME)"
	@echo "Compose files: $(COMPOSE_FILES)"
	@[ -f $(COMPOSE_FILE) ] && echo "$(GREEN)✓ $(COMPOSE_FILE) exists$(RESET)" || echo "$(RED)✗ $(COMPOSE_FILE) not found$(RESET)"
	@[ -f $(OVERRIDE_FILE) ] && echo "$(GREEN)✓ $(OVERRIDE_FILE) exists$(RESET)" || echo "$(YELLOW)! $(OVERRIDE_FILE) not found (optional)$(RESET)"
	@for df in $(DOCKERFILES); do \
		[ -f $$df ] && echo "$(GREEN)✓ $$df exists$(RESET)" || echo "$(RED)✗ $$df not found$(RESET)"; \
	done

lint: ## Lint Dockerfiles for best practices
	@printf "$(BOLD)$(BLUE)Linting Dockerfiles...$(RESET)\n"
	@if command -v hadolint >/dev/null 2>&1; then \
		for df in $(DOCKERFILES); do \
			if [ -f $$df ]; then \
				echo "$(BOLD)Linting $$df:$(RESET)"; \
				hadolint $$df || true; \
			else \
				echo "$(YELLOW)Skipping $$df (not found)$(RESET)"; \
			fi; \
		done; \
	else \
		echo "$(YELLOW)Warning: hadolint not installed. Cannot lint Dockerfiles.$(RESET)"; \
		echo "$(YELLOW)Install with: docker pull hadolint/hadolint$(RESET)"; \
	fi

# -----------------------------------------------------------------------------
# Service-specific Subcommands (Service name as argument)
# -----------------------------------------------------------------------------
.PHONY: logs enter push

logs:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make logs <service>"; \
		exit 1; \
	fi; \
	printf "$(BOLD)$(BLUE)Showing logs for service '$(SERVICE)'...$(RESET)\n"; \
	$(COMPOSE_CMD) logs -f $(SERVICE)

enter:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make enter <service>"; \
		exit 1; \
	fi; \
	printf "$(BOLD)$(BLUE)Entering container for service '$(SERVICE)'...$(RESET)\n"; \
	$(COMPOSE_CMD) exec $(SERVICE) /bin/sh

push:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Usage: make push <service>"; \
		exit 1; \
	fi; \
	IMAGE_TAG="$(REGISTRY)/$(OWNER)/$(SERVICE):$(TAG_SUFFIX)"; \
	printf "$(BOLD)$(BLUE)Tagging and pushing image for service '$(SERVICE)' as $$IMAGE_TAG...$(RESET)\n"; \
	docker tag $(OWNER)/$(SERVICE):latest $$IMAGE_TAG; \
	docker push $$IMAGE_TAG

# -----------------------------------------------------------------------------
# Default Target
# -----------------------------------------------------------------------------
.PHONY: all
all: help

.DEFAULT_GOAL := help

.PHONY: debug 
debug:
	@echo "CURDIR is: $(CURDIR)"
	@echo "Project name from CURDIR is: $(notdir $(CURDIR))"