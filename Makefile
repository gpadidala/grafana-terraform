# =============================================================================
# Grafana Enterprise Terraform - Makefile
# =============================================================================
#
# Usage:
#   make plan ENV=staging
#   make apply ENV=prod VERSION=1.2.3
#   make export
#   make version-bump TYPE=minor
#
# =============================================================================

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
ENV            ?= dev
TYPE           ?= patch
VERSION        ?= $(shell cat VERSION 2>/dev/null || echo "0.0.0")
SCRIPTS_DIR    := scripts
ENVIRONMENTS   := environments/$(ENV)
TF_PLAN_FILE   := tfplan-$(ENV)

# Colors for terminal output
BOLD   := $(shell tput bold 2>/dev/null || echo "")
GREEN  := $(shell tput setaf 2 2>/dev/null || echo "")
YELLOW := $(shell tput setaf 3 2>/dev/null || echo "")
RED    := $(shell tput setaf 1 2>/dev/null || echo "")
RESET  := $(shell tput sgr0 2>/dev/null || echo "")

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "$(BOLD)Grafana Terraform$(RESET) (env: $(GREEN)$(ENV)$(RESET), version: $(GREEN)$(VERSION)$(RESET))"
	@echo ""
	@echo "$(BOLD)Targets:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BOLD)Examples:$(RESET)"
	@echo "  make plan ENV=staging"
	@echo "  make apply ENV=prod VERSION=1.2.3"
	@echo "  make version-bump TYPE=minor"
	@echo ""

# ---------------------------------------------------------------------------
# Terraform Lifecycle
# ---------------------------------------------------------------------------
.PHONY: init
init: ## Initialize Terraform with backend config for ENV
	@echo "$(BOLD)Initializing Terraform for $(GREEN)$(ENV)$(RESET)..."
	terraform init \
		-backend-config="$(ENVIRONMENTS)/backend.hcl" \
		-reconfigure

.PHONY: validate
validate: ## Run format check and validation
	@echo "$(BOLD)Validating Terraform configuration...$(RESET)"
	terraform fmt -check -recursive -diff
	terraform validate

.PHONY: plan
plan: init ## Create an execution plan for ENV
	@echo "$(BOLD)Planning for $(GREEN)$(ENV)$(RESET) (version: $(VERSION))..."
	terraform plan \
		-var-file="$(ENVIRONMENTS)/terraform.tfvars" \
		-var="platform_version=$(VERSION)" \
		-out="$(TF_PLAN_FILE)"
	@echo ""
	@echo "$(GREEN)Plan saved to $(TF_PLAN_FILE).$(RESET)"
	@echo "Run '$(BOLD)make apply ENV=$(ENV)$(RESET)' to apply."

.PHONY: apply
apply: init ## Apply the plan for ENV
	@echo "$(BOLD)Applying Terraform for $(GREEN)$(ENV)$(RESET) (version: $(VERSION))..."
	terraform apply \
		-var-file="$(ENVIRONMENTS)/terraform.tfvars" \
		-var="platform_version=$(VERSION)"

.PHONY: destroy
destroy: init ## Destroy infrastructure for ENV (with confirmation)
	@echo "$(RED)$(BOLD)WARNING: This will destroy all resources in $(ENV)!$(RESET)"
	@echo ""
	@read -p "Type '$(ENV)' to confirm destruction: " confirm && \
		[ "$$confirm" = "$(ENV)" ] || { echo "$(YELLOW)Aborted.$(RESET)"; exit 1; }
	terraform destroy \
		-var-file="$(ENVIRONMENTS)/terraform.tfvars" \
		-var="platform_version=$(VERSION)"

# ---------------------------------------------------------------------------
# Dashboard Management
# ---------------------------------------------------------------------------
.PHONY: export
export: ## Export dashboards from Grafana instance
	@echo "$(BOLD)Exporting dashboards...$(RESET)"
	@bash $(SCRIPTS_DIR)/export-dashboards.sh

.PHONY: templatize
templatize: ## Replace hardcoded UIDs with template variables
	@echo "$(BOLD)Templatizing dashboards...$(RESET)"
	@bash $(SCRIPTS_DIR)/templatize-dashboards.sh

# ---------------------------------------------------------------------------
# Versioning
# ---------------------------------------------------------------------------
.PHONY: version-bump
version-bump: ## Bump version (TYPE=major|minor|patch)
	@bash $(SCRIPTS_DIR)/version-bump.sh $(TYPE)

.PHONY: version
version: ## Show current version
	@echo "$(VERSION)"

# ---------------------------------------------------------------------------
# Quality
# ---------------------------------------------------------------------------
.PHONY: lint
lint: ## Run tflint and validate dashboard JSON
	@echo "$(BOLD)Running linters...$(RESET)"
	@echo ""
	@echo "--- Terraform Format ---"
	terraform fmt -check -recursive -diff || true
	@echo ""
	@echo "--- TFLint ---"
	@if command -v tflint &>/dev/null; then \
		tflint --init && tflint; \
	else \
		echo "$(YELLOW)tflint not installed. Skipping.$(RESET)"; \
	fi
	@echo ""
	@echo "--- Dashboard JSON Validation ---"
	@errors=0; \
	for f in $$(find dashboards/ -name "*.json" -o -name "*.json.tmpl" 2>/dev/null); do \
		if ! jq empty "$$f" 2>/dev/null; then \
			echo "$(RED)INVALID:$(RESET) $$f"; \
			errors=$$((errors + 1)); \
		fi; \
	done; \
	if [ $$errors -gt 0 ]; then \
		echo "$(RED)Found $$errors invalid JSON file(s).$(RESET)"; \
		exit 1; \
	else \
		echo "$(GREEN)All dashboard JSON files are valid.$(RESET)"; \
	fi

.PHONY: docs
docs: ## Generate Terraform documentation
	@echo "$(BOLD)Generating Terraform docs...$(RESET)"
	@if command -v terraform-docs &>/dev/null; then \
		terraform-docs markdown table . > TERRAFORM.md; \
		echo "$(GREEN)Documentation written to TERRAFORM.md$(RESET)"; \
	else \
		echo "$(YELLOW)terraform-docs not installed.$(RESET)"; \
		echo "Install: brew install terraform-docs"; \
		exit 1; \
	fi

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
.PHONY: clean
clean: ## Remove generated/cached files
	@echo "$(BOLD)Cleaning up...$(RESET)"
	rm -rf .terraform/
	rm -f .terraform.lock.hcl
	rm -f *.tfplan
	rm -f tfplan-*
	rm -f crash.log
	@echo "$(GREEN)Clean.$(RESET)"
