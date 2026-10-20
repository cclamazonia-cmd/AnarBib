# =============================================================================
# AnarBib — Automatisation Multi-Architecture & Déploiement Zero-Build
# =============================================================================
# Fournit les commandes de construction, publication et exploitation conteneurisée.
# Registre officiel : hub.unionlibertaireanarchiste.org/anarbib
# =============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

REGISTRY ?= hub.unionlibertaireanarchiste.org/anarbib
IMAGE_WEB ?= $(REGISTRY)/web
VERSION ?= $(shell git describe --tags --always 2>/dev/null || echo "latest")
COMMIT_SHA ?= $(shell git rev-parse HEAD 2>/dev/null || echo "")
PLATFORMS ?= linux/amd64,linux/arm64
BUILDER ?= anarco-multi

# Versions épinglées lues dynamiquement depuis deploy/.env.example
ENV_EXAMPLE := deploy/.env.example
POSTGRES_TAG ?= $(shell grep -E '^POSTGRES_TAG=' $(ENV_EXAMPLE) | cut -d= -f2)
POSTGREST_TAG ?= $(shell grep -E '^POSTGREST_TAG=' $(ENV_EXAMPLE) | cut -d= -f2)
GOTRUE_TAG ?= $(shell grep -E '^GOTRUE_TAG=' $(ENV_EXAMPLE) | cut -d= -f2)
STORAGE_TAG ?= $(shell grep -E '^STORAGE_TAG=' $(ENV_EXAMPLE) | cut -d= -f2)
EDGE_RUNTIME_TAG ?= $(shell grep -E '^EDGE_RUNTIME_TAG=' $(ENV_EXAMPLE) | cut -d= -f2)
CADDY_TAG ?= $(shell grep -E '^CADDY_TAG=' $(ENV_EXAMPLE) | cut -d= -f2)

# Détection et création du compilateur buildx si nécessaire
.PHONY: check-builder
check-builder:
	@if ! docker buildx inspect $(BUILDER) >/dev/null 2>&1; then \
		echo "› Initialisation du compilateur buildx $(BUILDER)..."; \
		docker buildx create --name $(BUILDER) --driver docker-container --bootstrap --use; \
	else \
		docker buildx use $(BUILDER) >/dev/null 2>&1 || true; \
	fi

.PHONY: help
help:
	@echo "AnarBib — Commandes d'automatisation"
	@echo ""
	@echo "Usage :"
	@echo "  make <cible> [OPTIONS]"
	@echo ""
	@echo "Cibles disponibles :"
	@echo "  build-web            Construire l'image anarbib-web localement (architecture hôte)"
	@echo "  build-web-multi      Construire l'image anarbib-web en multi-arch ($(PLATFORMS))"
	@echo "  push-web             Construire et publier anarbib-web vers Zot ($(REGISTRY)/web)"
	@echo "  sync-backend         Synchroniser les 6 conteneurs backend (multi-arch) vers Zot via Skopeo"
	@echo "  up-prebuilt          Démarrer la pile complète pré-compilée (Zero-Build)"
	@echo "  down                 Arrêter les conteneurs en cours d'exécution"
	@echo ""
	@echo "Variables configurables :"
	@echo "  REGISTRY             Registre OCI cible (défaut : $(REGISTRY))"
	@echo "  VERSION              Étiquette de version (défaut : $(VERSION))"
	@echo "  PLATFORMS            Architectures ciblées (défaut : $(PLATFORMS))"
	@echo ""

.PHONY: build-web
build-web:
	@echo "› Construction locale de l'image web..."
	docker build \
		--build-arg COMMIT_SHA=$(COMMIT_SHA) \
		-f Dockerfile.web \
		-t $(IMAGE_WEB):local \
		-t $(IMAGE_WEB):$(VERSION) \
		$(if $(COMMIT_SHA),-t $(IMAGE_WEB):$(COMMIT_SHA),) \
		.
	@echo "✓ Image construite avec succès : $(IMAGE_WEB):$(VERSION)"

.PHONY: build-web-multi
build-web-multi: check-builder
	@echo "› Construction multi-architecture ($(PLATFORMS))..."
	docker buildx build \
		--builder $(BUILDER) \
		--platform $(PLATFORMS) \
		--build-arg COMMIT_SHA=$(COMMIT_SHA) \
		-f Dockerfile.web \
		-t $(IMAGE_WEB):$(VERSION) \
		-t $(IMAGE_WEB):latest \
		$(if $(COMMIT_SHA),-t $(IMAGE_WEB):$(COMMIT_SHA),) \
		.
	@echo "✓ Image multi-architecture compilée."

.PHONY: push-web
push-web: check-builder
	@echo "› Compilation et publication sur $(REGISTRY)/web..."
	docker buildx build \
		--builder $(BUILDER) \
		--platform $(PLATFORMS) \
		--build-arg COMMIT_SHA=$(COMMIT_SHA) \
		-f Dockerfile.web \
		-t $(IMAGE_WEB):$(VERSION) \
		-t $(IMAGE_WEB):latest \
		$(if $(COMMIT_SHA),-t $(IMAGE_WEB):$(COMMIT_SHA),) \
		--push \
		.
	@echo "✓ Image anarbib/web publiée avec succès sur $(REGISTRY)."

.PHONY: sync-backend
sync-backend:
	@echo "› Synchronisation des images backend vers $(REGISTRY)..."
	skopeo copy --src-no-creds --all docker://docker.io/supabase/postgres:$(POSTGRES_TAG) docker://$(REGISTRY)/postgres:$(POSTGRES_TAG)
	skopeo copy --src-no-creds --all docker://docker.io/postgrest/postgrest:$(POSTGREST_TAG) docker://$(REGISTRY)/postgrest:$(POSTGREST_TAG)
	skopeo copy --src-no-creds --all docker://docker.io/supabase/gotrue:$(GOTRUE_TAG) docker://$(REGISTRY)/gotrue:$(GOTRUE_TAG)
	skopeo copy --src-no-creds --all docker://docker.io/supabase/storage-api:$(STORAGE_TAG) docker://$(REGISTRY)/storage-api:$(STORAGE_TAG)
	skopeo copy --src-no-creds --all docker://docker.io/supabase/edge-runtime:$(EDGE_RUNTIME_TAG) docker://$(REGISTRY)/edge-runtime:$(EDGE_RUNTIME_TAG)
	skopeo copy --src-no-creds --all docker://docker.io/library/caddy:$(CADDY_TAG) docker://$(REGISTRY)/caddy:$(CADDY_TAG)
	@echo "✓ Toutes les images backend sont synchronisées en multi-architecture sur $(REGISTRY)."

.PHONY: up-prebuilt
up-prebuilt:
	@echo "› Démarrage de la pile pré-compilée..."
	./install.sh --prebuilt

.PHONY: down
down:
	@echo "› Arrêt des conteneurs AnarBib..."
	./install.sh --stop
