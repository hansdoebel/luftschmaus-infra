SHELL := /bin/bash

KUBE_DIR := kubernetes
CRDS_SCHEMA := https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json

.PHONY: lint yamllint kubeconform kustomize compose help

lint: yamllint kubeconform kustomize compose
	@printf '\033[32m[✓]\033[0m All checks passed\n'

yamllint:
	@if ! command -v yamllint >/dev/null 2>&1; then \
		printf '\033[33m[-]\033[0m yamllint not installed (brew install yamllint)\n'; \
	else \
		printf '  Running yamllint...\n'; \
		yamllint -d '{extends: relaxed, rules: {line-length: {max: 200}}}' $(KUBE_DIR)/ docker-compose.yml prometheus.yml \
			&& printf '\033[32m[✓]\033[0m yamllint\n' \
			|| { printf '\033[31m[X]\033[0m yamllint\n'; exit 1; }; \
	fi

kubeconform:
	@if ! command -v kubeconform >/dev/null 2>&1; then \
		printf '\033[33m[-]\033[0m kubeconform not installed (brew install kubeconform)\n'; \
	else \
		printf '  Running kubeconform...\n'; \
		kubeconform -strict -summary -ignore-missing-schemas \
			-schema-location default \
			-schema-location '$(CRDS_SCHEMA)' \
			$(KUBE_DIR)/ \
			&& printf '\033[32m[✓]\033[0m kubeconform\n' \
			|| { printf '\033[31m[X]\033[0m kubeconform\n'; exit 1; }; \
	fi

kustomize:
	@printf '  Running kustomize build...\n'
	@kubectl kustomize $(KUBE_DIR)/infrastructure/external-secrets/ >/dev/null \
		&& kubectl kustomize $(KUBE_DIR)/infrastructure/external-secrets/crs/ >/dev/null \
		&& printf '\033[32m[✓]\033[0m kustomize\n' \
		|| { printf '\033[31m[X]\033[0m kustomize\n'; exit 1; }

compose:
	@printf '  Running docker compose config...\n'
	@docker compose config --quiet 2>/dev/null \
		&& printf '\033[32m[✓]\033[0m docker compose\n' \
		|| { printf '\033[31m[X]\033[0m docker compose\n'; exit 1; }

help:
	@echo "Targets:"
	@echo "  make lint         Run all checks"
	@echo "  make yamllint     YAML syntax and style"
	@echo "  make kubeconform  Kubernetes schema validation"
	@echo "  make kustomize    Kustomize build validation"
	@echo "  make compose      Docker Compose validation"
