#!/bin/bash
# ============================================================================
# Script de nettoyage du dossier docs/ — AnarBib
# ============================================================================
# Date     : 20 mai 2026
# Auteur   : Xavier + Claude
# Objet    : Nettoyage complet du dossier docs/ :
#            - archivage des anciennes versions de backlog
#            - archivage des prompts de reprise obsolètes
#            - intégration de la doctrine fusionnée (12/05 + v2 #150)
#            - migration du dossier paquets/ vers decisions/
#
# PRÉREQUIS : ce script suppose que le nettoyage de docs/specs/ a déjà été
#             fait via cleanup-specs-corpus.sh (Bloc 4 précédent). Les deux
#             scripts sont indépendants mais complémentaires.
#
# À exécuter depuis la racine du repo `anarbib-app` :
#   cd "C:\Users\accat\Claude's AnarBib\anarbib-app"
#   bash scripts/cleanup-docs-corpus.sh
#
# Idempotent : peut être ré-exécuté sans dommage.
# ============================================================================

set -euo pipefail

# Détection du dossier docs/
if [[ -d "docs" && -d "docs/decisions" ]]; then
    DOCS_DIR="docs"
elif [[ -d "decisions" && -d "backlogs" ]]; then
    DOCS_DIR="."
else
    echo "❌ Erreur : impossible de localiser docs/. Exécuter depuis la racine du repo."
    exit 1
fi

cd "$DOCS_DIR"
echo "📁 Working in: $(pwd)"
echo ""

# Détection git
if git rev-parse --git-dir > /dev/null 2>&1; then
    USE_GIT=true
    echo "✅ Repo git détecté, utilisation de 'git mv' / 'git rm'"
else
    USE_GIT=false
    echo "⚠️  Pas de repo git détecté, utilisation de 'mv' / 'rm'"
fi
echo ""

# ============================================================================
# Helpers
# ============================================================================
safe_move() {
    local src="$1" dst="$2" reason="$3"
    if [[ ! -f "$src" ]]; then
        echo "  ⏭️  $src : déjà absent (idempotence)"
        return 0
    fi
    if [[ -f "$dst" ]]; then
        echo "  ⚠️  $dst existe déjà — skip pour éviter écrasement"
        return 0
    fi
    echo "  ➡️  $src"
    echo "      → $dst"
    echo "      ($reason)"
    if [[ "$USE_GIT" == "true" ]]; then git mv "$src" "$dst"; else mv "$src" "$dst"; fi
}

safe_delete() {
    local file="$1" reason="$2"
    if [[ ! -f "$file" ]]; then
        echo "  ⏭️  $file : déjà absent (idempotence)"
        return 0
    fi
    echo "  🗑️  $file"
    echo "      ($reason)"
    if [[ "$USE_GIT" == "true" ]]; then git rm "$file"; else rm "$file"; fi
}

ensure_dir() {
    if [[ ! -d "$1" ]]; then
        echo "  📁 Création du dossier $1"
        mkdir -p "$1"
    fi
}

# ============================================================================
# Action 1 : Archivage des anciennes versions de backlog
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BACKLOGS — archivage des 9 anciennes versions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ensure_dir "backlogs/archive"

safe_move "backlogs/AnarBib-Backlog-2026-05-13-v8.docx" \
          "backlogs/archive/AnarBib-Backlog-archive-2026-05-13-v8.docx" \
          "ancienne version (lignée v8 historique)"
safe_move "backlogs/AnarBib-Backlog-2026-05-14-v10.md" \
          "backlogs/archive/AnarBib-Backlog-archive-2026-05-14-v10.md" \
          "ancienne version"
safe_move "backlogs/AnarBib-Backlog-2026-05-14-v11.md" \
          "backlogs/archive/AnarBib-Backlog-archive-2026-05-14-v11.md" \
          "ancienne version"
safe_move "backlogs/AnarBib-Backlog-2026-05-15-v12.md" \
          "backlogs/archive/AnarBib-Backlog-archive-2026-05-15-v12.md" \
          "ancienne version"
safe_move "backlogs/AnarBib-Backlog-2026-05-15-v13.md" \
          "backlogs/archive/AnarBib-Backlog-archive-2026-05-15-v13.md" \
          "ancienne version"
safe_move "backlogs/AnarBib-Backlog-2026-05-15-v14.md" \
          "backlogs/archive/AnarBib-Backlog-archive-2026-05-15-v14.md" \
          "ancienne version"
safe_move "backlogs/AnarBib-Backlog-2026-05-17-v15.md" \
          "backlogs/archive/AnarBib-Backlog-archive-2026-05-17-v15.md" \
          "ancienne version (dernière de la lignée session par session)"
safe_move "backlogs/AnarBib-Backlog-2026-05-18-v6.docx" \
          "backlogs/archive/AnarBib-Backlog-archive-2026-05-18-v6.docx" \
          "ancienne version (lignée v6 historique)"
safe_move "backlogs/BACKLOG_chantiers_H_I_J_issus_reunion_BTL_2026-05-18.md" \
          "backlogs/archive/BACKLOG_chantiers_H_I_J_issus_reunion_BTL_archive-2026-05-18.md" \
          "chantiers H/I/J intégrés dans le backlog v8 du 20/05"

echo ""
echo "  ℹ️  IMPORTANT : placer manuellement le backlog v8 du 20/05"
echo "      (AnarBib-Backlog-2026-05-20-v8.docx) à la racine de backlogs/"
echo "      si ce n'est pas déjà fait."
echo ""

# ============================================================================
# Action 2 : Archivage des prompts de reprise obsolètes
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 PROMPTS-REPRISE — archivage des 4 mémentos de chantiers clos"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ensure_dir "decisions/archive/prompts-reprise"

safe_move "decisions/Prompt-Reprise-98B-Paquet-B-Transitions.md" \
          "decisions/archive/prompts-reprise/Prompt-Reprise-98B-Paquet-B-Transitions.md" \
          "chantier #98 clos le 19/05"
safe_move "decisions/Prompt-Reprise-98B-Paquets-B5-B6.md" \
          "decisions/archive/prompts-reprise/Prompt-Reprise-98B-Paquets-B5-B6.md" \
          "chantier #98 clos le 19/05"
safe_move "decisions/Prompt-Reprise-Chantier-150-audit-securite.md" \
          "decisions/archive/prompts-reprise/Prompt-Reprise-Chantier-150-audit-securite.md" \
          "chantier #150 clos le 18/05"
safe_move "decisions/Prompt-Reprise-Phase5-Cloture-114.md" \
          "decisions/archive/prompts-reprise/Prompt-Reprise-Phase5-Cloture-114.md" \
          "chantier #114 clos le 14/05"

echo ""

# ============================================================================
# Action 3 : Doctrine création objets sécurisés — fusion appliquée
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 DOCTRINE OBJETS SÉCURISÉS — archivage doublon + v2 fusionné"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ensure_dir "decisions/archive"

# Le fichier .md du 12/05 a été remplacé par la version fusionnée (fournie séparément).
# Ce script archive le .docx doublon et le v2 désormais intégré.

safe_move "decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.docx" \
          "decisions/archive/CHANTIER_doctrine_creation_objets_securises_2026-05-12.docx" \
          "doublon ancien format .docx du document .md (même contenu)"
safe_move "decisions/CHANTIER_doctrine_creation_objets_securises_v2_2026-05-18.md" \
          "decisions/archive/CHANTIER_doctrine_creation_objets_securises_v2_2026-05-18.md" \
          "doctrine v2 désormais fusionnée dans le .md du 12/05 (Partie II)"

echo ""
echo "  ℹ️  IMPORTANT : remplacer manuellement le fichier"
echo "      decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md"
echo "      par la version FUSIONNÉE fournie séparément (Partie I + Partie II)."
echo ""

# ============================================================================
# Action 4 : Migration du dossier paquets/ vers decisions/
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 PAQUETS/ — migration du fichier unique vers decisions/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

safe_move "paquets/paquet-26-decisions.md" \
          "decisions/CHANTIER_paquet_26_consultations_2026-05-13.md" \
          "fusion du dossier paquets/ (1 seul fichier) dans decisions/"

# Suppression du dossier paquets/ s'il est vide
if [[ -d "paquets" ]]; then
    if [[ -z "$(ls -A paquets 2>/dev/null)" ]]; then
        echo "  📁 Suppression du dossier paquets/ (vide après migration)"
        rmdir paquets
    else
        echo "  ⚠️  Dossier paquets/ non vide — conservé. Contenu restant :"
        ls -la paquets/
    fi
fi

echo ""

# ============================================================================
# Résumé final
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ NETTOYAGE docs/ TERMINÉ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📊 État final de docs/ (niveau racine + sous-dossiers) :"
echo ""
echo "  docs/ (racine) :"
ls -la *.md 2>/dev/null | awk '{print "    " $NF}' | sort
echo ""
echo "  docs/backlogs/ :"
ls backlogs/*.docx backlogs/*.md 2>/dev/null | sed 's|^|    |'
echo "    └── archive/ : $(ls backlogs/archive/ 2>/dev/null | wc -l) fichiers"
echo ""
echo "  docs/decisions/ : $(ls decisions/*.md decisions/*.docx 2>/dev/null | wc -l) fichiers actifs"
echo "    └── archive/ : $(find decisions/archive -type f 2>/dev/null | wc -l) fichiers"
echo ""

echo "📋 ÉTAPES MANUELLES À NE PAS OUBLIER :"
echo ""
echo "  1. Remplacer decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md"
echo "     par la version FUSIONNÉE (Partie I + Partie II)."
echo ""
echo "  2. Placer le backlog v8 du 20/05 à la racine de backlogs/ :"
echo "     AnarBib-Backlog-2026-05-20-v8.docx"
echo ""
echo "  3. Vérifier que les 4 fichiers INDEX sont en place :"
echo "     docs/INDEX.md, docs/specs/INDEX.md, docs/specs/INVENTAIRE.md,"
echo "     docs/decisions/INDEX.md, docs/backlogs/INDEX.md"
echo ""
echo "  4. Vérifier puis committer :"
echo "       git status"
echo "       git add -A docs/"
echo "       git commit -m 'docs: nettoyage corpus docs/ + index de navigation"
echo ""
echo "       - Archivage 9 anciennes versions de backlog"
echo "       - Archivage 4 prompts de reprise (chantiers #98/#114/#150 clos)"
echo "       - Fusion doctrine objets sécurisés (12/05 + v2 #150) en un document"
echo "       - Migration dossier paquets/ vers decisions/"
echo "       - Ajout INDEX.md (général + decisions + backlogs)"
echo "       - Bloc 5 du marathon de nettoyage documentaire du 20/05'"
echo ""
echo "       git push"
echo ""
echo "✨ Fini."
