#!/bin/bash
# ============================================================================
# Script de nettoyage du corpus de specs AnarBib
# ============================================================================
# Date     : 20 mai 2026
# Auteur   : Xavier + Claude
# Objet    : Archivage des anciennes versions de specs + suppression d'un .bak
#
# À exécuter depuis la racine du repo `anarbib-app`, soit :
#   cd "C:\Users\accat\Claude's AnarBib\anarbib-app"
#   bash scripts/cleanup-specs-corpus.sh
#
# Ou directement depuis docs/specs/ :
#   cd docs/specs
#   bash ../../scripts/cleanup-specs-corpus.sh
#
# Idempotent : peut être ré-exécuté sans dommage (vérifie l'existence
# avant chaque action).
# ============================================================================

set -euo pipefail

# Détection du dossier de travail
if [[ -d "docs/specs" ]]; then
    SPECS_DIR="docs/specs"
elif [[ -d "../../docs/specs" ]]; then
    SPECS_DIR="../../docs/specs"
elif [[ -f "INDEX.md" && -d "archive" ]]; then
    SPECS_DIR="."
else
    echo "❌ Erreur : impossible de localiser docs/specs/. Exécuter depuis racine du repo ou depuis docs/specs/."
    exit 1
fi

cd "$SPECS_DIR"
echo "📁 Working in: $(pwd)"
echo ""

# ============================================================================
# Vérification préalable : on est bien dans un dossier git
# ============================================================================
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "⚠️  Attention : ce dossier n'est pas dans un repo git."
    echo "    Le script utilisera 'mv' au lieu de 'git mv'."
    echo "    Tu auras à add/commit manuellement ensuite."
    USE_GIT=false
else
    USE_GIT=true
    echo "✅ Repo git détecté, utilisation de 'git mv'"
fi
echo ""

# ============================================================================
# Fonction helper : déplacement sécurisé
# ============================================================================
safe_move() {
    local src="$1"
    local dst="$2"
    local reason="$3"

    if [[ ! -f "$src" ]]; then
        echo "  ⏭️  $src : déjà absent (idempotence)"
        return 0
    fi

    if [[ -f "$dst" ]]; then
        echo "  ⚠️  $dst existe déjà — skip pour éviter écrasement"
        return 0
    fi

    echo "  ➡️  $src → $dst"
    echo "      ($reason)"

    if [[ "$USE_GIT" == "true" ]]; then
        git mv "$src" "$dst"
    else
        mv "$src" "$dst"
    fi
}

safe_delete() {
    local file="$1"
    local reason="$2"

    if [[ ! -f "$file" ]]; then
        echo "  ⏭️  $file : déjà absent (idempotence)"
        return 0
    fi

    echo "  🗑️  Suppression : $file"
    echo "      ($reason)"

    if [[ "$USE_GIT" == "true" ]]; then
        git rm "$file"
    else
        rm "$file"
    fi
}

# ============================================================================
# Vérification : le dossier archive/ existe
# ============================================================================
if [[ ! -d "archive" ]]; then
    echo "📁 Création du dossier archive/"
    mkdir -p archive
fi

# ============================================================================
# Action 1 : Archivage des 6 specs ancienne version
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 ARCHIVAGE — 6 specs ancienne version + 1 brouillon obsolète"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

safe_move \
    "spec-administrateur-reseau.md" \
    "archive/spec-administrateur-reseau-archive-v0.3.1.md" \
    "v0.3.1 remplacée par spec-administrateur-reseau-v0.4.md"

safe_move \
    "spec-flux-consultations.md" \
    "archive/spec-flux-consultations-archive-v2.1.md" \
    "v2.1 remplacée par spec-flux-consultations-v2.2.md"

safe_move \
    "spec-onboarding-biblioteca.md" \
    "archive/spec-onboarding-biblioteca-archive-v1.1.md" \
    "v1.1 remplacée par spec-onboarding-biblioteca-v2.0.md"

safe_move \
    "spec-profils-bibliotheque.md" \
    "archive/spec-profils-bibliotheque-archive-v0.4.md" \
    "v0.4 ancienne remplacée par spec-profils-bibliotheque-v0_7.md"

safe_move \
    "spec-profils-bibliotheque-v0.5.md" \
    "archive/spec-profils-bibliotheque-archive-v0.5.md" \
    "intermédiaire remplacée par spec-profils-bibliotheque-v0_7.md"

safe_move \
    "spec-profils-bibliotheque-v0.6.md" \
    "archive/spec-profils-bibliotheque-archive-v0.6.md" \
    "intermédiaire remplacée par spec-profils-bibliotheque-v0_7.md"

safe_move \
    "spec-flux-consultation-locale.md" \
    "archive/spec-flux-consultation-locale-archive-v0.md" \
    "brouillon du 10/05 absorbé dans spec-flux-consultations.md du 15/05"

echo ""

# ============================================================================
# Action 2 : Suppression du backup .bak périmé
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗑️  SUPPRESSION — 1 backup automatique périmé"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

safe_delete \
    "spec-profils-bibliotheque-v0.3.md.bak" \
    "backup automatique du 13/05 antérieur à v0.5/v0.6/v0.7, pas de valeur historique"

echo ""

# ============================================================================
# Résumé final
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ NETTOYAGE TERMINÉ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📊 État final du dossier docs/specs/ :"
echo ""
ls -la *.md 2>/dev/null | awk '{print "    " $NF}' | sort
echo ""

echo "📊 État final du dossier docs/specs/archive/ :"
echo ""
ls -la archive/*.md 2>/dev/null | awk '{print "    " $NF}' | sort
echo ""

echo "📋 Prochaines étapes :"
echo ""
echo "  1. Vérifier le résultat :"
echo "       git status"
echo ""
echo "  2. Si tout est OK, committer :"
echo "       git add -A docs/specs/"
echo "       git commit -m 'docs(specs): nettoyage corpus + INDEX/INVENTAIRE (post-réécriture v2.0/v0.4/v2.2)"
echo ""
echo "       - Archivage 6 specs anciennes versions (admin-reseau v0.3.1, consultas v2.1,"
echo "         onboarding v1.1, profils v0.4/v0.5/v0.6)"
echo "       - Archivage brouillon spec-flux-consultation-locale.md (10/05)"
echo "       - Suppression backup .bak périmé (profils v0.3)"
echo "       - Ajout INDEX.md (navigation rapide) et INVENTAIRE.md (description détaillée)"
echo "       - Bloc 4 du marathon de réécriture spec du 20/05/2026'"
echo ""
echo "  3. Pousser :"
echo "       git push  # (pousse vers Codeberg + GitHub via dual push)"
echo ""

echo "✨ Fini."
