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
PLATFORMS ?= linux/amd64,linux/arm64
BUILDER ?= anarco-multi

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
	@echo "  sync-backend         Synchroniser les 5 conteneurs Supabase et Caddy vers Zot via Skopeo"
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
	docker build -f Dockerfile.web -t $(IMAGE_WEB):local -t $(IMAGE_WEB):$(VERSION) .
	@echo "✓ Image construite avec succès : $(IMAGE_WEB):$(VERSION)"

.PHONY: build-web-multi
build-web-multi: check-builder
	@echo "› Construction multi-architecture ($(PLATFORMS))..."
	docker buildx build \
		--builder $(BUILDER) \
		--platform $(PLATFORMS) \
		-f Dockerfile.web \
		-t $(IMAGE_WEB):$(VERSION) \
		-t $(IMAGE_WEB):latest \
		.
	@echo "✓ Image multi-architecture compilée."

.PHONY: push-web
push-web: check-builder
	@echo "› Compilation et publication sur $(REGISTRY)/web..."
	docker buildx build \
		--builder $(BUILDER) \
		--platform $(PLATFORMS) \
		-f Dockerfile.web \
		-t $(IMAGE_WEB):$(VERSION) \
		-t $(IMAGE_WEB):latest \
		--push \
		.
	@echo "✓ Image anarbib/web publiée avec succès sur $(REGISTRY)."

.PHONY: sync-backend
sync-backend:
	@echo "› Synchronisation des images backend vers $(REGISTRY)..."
	skopeo copy --src-no-creds --all docker://docker.io/supabase/postgres:17.6.1.136 docker://$(REGISTRY)/postgres:17.6.1.136
	skopeo copy --src-no-creds --all docker://docker.io/postgrest/postgrest:v14.12 docker://$(REGISTRY)/postgrest:v14.12
	skopeo copy --src-no-creds --all docker://docker.io/supabase/gotrue:v2.197.0 docker://$(REGISTRY)/gotrue:v2.197.0
	skopeo copy --src-no-creds --all docker://docker.io/supabase/storage-api:v1.78.0 docker://$(REGISTRY)/storage-api:v1.78.0
	skopeo copy --src-no-creds --all docker://docker.io/supabase/edge-runtime:v1.74.0 docker://$(REGISTRY)/edge-runtime:v1.74.0
	skopeo copy --src-no-creds --override-os linux docker://docker.io/library/caddy:2 docker://$(REGISTRY)/caddy:2
	@echo "✓ Toutes les images backend sont synchronisées sur $(REGISTRY)."

.PHONY: up-prebuilt
up-prebuilt:
	@echo "› Démarrage de la pile pré-compilée..."
	./install.sh --prebuilt

.PHONY: down
down:
	@echo "› Arrêt des conteneurs AnarBib..."
	./install.sh --stop
