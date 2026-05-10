# @file Makefile
# @package winalux-core
# @description
#   Orchestration entry point for Winalux.
#   Uses explicit arguments to distinguish between target nodes and image sources.

# --- INFRASTRUCTURE PARAMETERS ---
TARGET_NODE  ?= local_dev          # Target group from inventory (local_dev or remote_pi)
USE_LOCAL_IMAGE ?= false           # If true, use 'localhost/' images instead of Docker Hub

# --- REMOTE ACCESS (Optional) ---
USER         ?= pi
IP           ?= 192.XXX.0.XX
KEY          ?= ~/.ssh/ansible-raspberry

# --- PATHS ---
INVENTORY     = inventory/hosts.yml
VAULT_PASS    = .vault_pass
DEPLOY_PB     = playbooks/deploy_dev.yml
BUILD_PB      = playbooks/build_multiarch.yml

# --- ANSIBLE COMMAND ---
ANSIBLE_CMD   = uv run ansible-playbook -i $(INVENTORY) --vault-password-file $(VAULT_PASS)

.PHONY: help deploy ps

help: ## 📖 Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

build: ## 🏗️ Build Multi-Arch images (Usage: make build push=true)
	@echo "Starting multi-arch build..."
	$(ANSIBLE_CMD) $(BUILD_PB) -e "push_to_hub=$(if $(push),$(push),false)"

deploy: ## 🚀 Deploy environments
	@echo "Deploying to: $(TARGET_NODE) (Local image: $(USE_LOCAL_IMAGE))"
	$(ANSIBLE_CMD) $(DEPLOY_PB) \
		--limit $(TARGET_NODE) \
		-e "winalux_use_local_image=$(USE_LOCAL_IMAGE)"
