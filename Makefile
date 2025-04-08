# =============================================================================
# Enhanced Docker RTMP Server Makefile
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration Variables
# -----------------------------------------------------------------------------
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

DOCKERFILES = pi-obs-container/Dockerfile.arm64 rtmp-server/Dockerfile metadata-service/Dockerfile

# Enable colors
BOLD    = \033[1m
RED     = \033[31m
GREEN   = \033[32m
YELLOW  = \033[33m
BLUE    = \033[34m
MAGENTA = \033[35m
CYAN    = \033[36m
RESET   = \033[0m

# -----------------------------------------------------------------------------
# Help Target
# -----------------------------------------------------------------------------
.PHONY: help
help: ## Display this help text
	@printf "$(BOLD)Usage:$(RESET)\n"
	@printf "  make [target]\n\n"
	@printf "$(BOLD)Available targets:$(RESET)\n"
	# @awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'

# -----------------------------------------------------------------------------
# Main Docker Compose Commands
# -----------------------------------------------------------------------------
.PHONY: up down restart logs status clean build rebuild

up: ## Start all services (build if needed)
	@printf "$(BOLD)$(GREEN)Starting services for $(PROJECT_NAME)...$(RESET)\n"
	$(COMPOSE_CMD) $(COMPOSE_FILES) up -d --build
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

logs: ## View logs from all services
	@printf "$(BOLD)$(BLUE)Showing logs for $(PROJECT_NAME)...$(RESET)\n"
	$(COMPOSE_CMD) logs -f

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

prune: ## Remove all unused containers, networks, images, and volumes
	@printf "$(BOLD)$(RED)Pruning Docker system...$(RESET)\n"
	@read -p "$(BOLD)$(RED)WARNING: This will remove all unused Docker resources. Continue? [y/N] $(RESET)" confirm; \
	[[ $$confirm == [yY] || $$confirm == [yY][eE][sS] ]] || exit 1
	docker system prune -af --volumes
	@printf "$(BOLD)$(GREEN)Docker system pruned.$(RESET)\n"

rebuild-images: ## Force rebuild all project images
	@printf "$(BOLD)$(YELLOW)Rebuilding all images for $(PROJECT_NAME)...$(RESET)\n"
	-docker rmi -f $$(docker images "cdaprod*" -q) 2>/dev/null || true
	$(MAKE) build
	@printf "$(BOLD)$(GREEN)Images rebuilt.$(RESET)\n"

inspect: ## Inspect the running containers
	@printf "$(BOLD)$(BLUE)Inspecting running containers for $(PROJECT_NAME):$(RESET)\n"
	@for container in $$($(COMPOSE_CMD) ps -q); do \
		if [ -n "$$container" ]; then \
			echo "$(BOLD)$(CYAN)$$container:$(RESET)"; \
			docker inspect --format='$(BOLD)Image:$(RESET) {{.Config.Image}}' $$container; \
			docker inspect --format='$(BOLD)State:$(RESET) {{.State.Status}}' $$container; \
			docker inspect --format='$(BOLD)Mounts:$(RESET) {{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' $$container; \
			echo; \
		fi; \
	done

check-env: ## Verify environment is properly configured
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
# Service-specific Commands
# -----------------------------------------------------------------------------
.PHONY: rtmp-logs metadata-logs pi-obs-logs enter-rtmp enter-metadata enter-pi-obs

rtmp-logs: ## View logs for the RTMP server
	@printf "$(BOLD)$(BLUE)Showing logs for RTMP server...$(RESET)\n"
	$(COMPOSE_CMD) logs -f rtmp-server

metadata-logs: ## View logs for the metadata service
	@printf "$(BOLD)$(BLUE)Showing logs for metadata service...$(RESET)\n"
	$(COMPOSE_CMD) logs -f metadata-service

pi-obs-logs: ## View logs for the Pi OBS container
	@printf "$(BOLD)$(BLUE)Showing logs for Pi OBS container...$(RESET)\n"
	$(COMPOSE_CMD) logs -f pi-obs

enter-rtmp: ## Enter the RTMP server container shell
	@printf "$(BOLD)$(BLUE)Entering RTMP server container...$(RESET)\n"
	$(COMPOSE_CMD) exec rtmp-server /bin/sh

enter-metadata: ## Enter the metadata service container shell
	@printf "$(BOLD)$(BLUE)Entering metadata service container...$(RESET)\n"
	$(COMPOSE_CMD) exec metadata-service /bin/sh

enter-pi-obs: ## Enter the Pi OBS container shell
	@printf "$(BOLD)$(BLUE)Entering Pi OBS container...$(RESET)\n"
	$(COMPOSE_CMD) exec pi-obs /bin/sh

.PHONY: all
all: help  ## Alias for help (default)

# Default target
.DEFAULT_GOAL := help

.PHONY: debug 

debug:
	@echo "CURDIR is: $(CURDIR)"
	@echo "Project name from CURDIR is: $(notdir $(CURDIR))"