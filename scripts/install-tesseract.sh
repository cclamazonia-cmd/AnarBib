#!/usr/bin/env bash
# install-tesseract.sh — vendorise tesseract.js pour AnarBib (POC OCR navigateur, piste B)
#
# Session : OCR import navigateur (piste B)
# Auteur  : Claude Code (depuis WSL — règle d'or)
#
# Pourquoi ce script plutôt que committer les assets :
#   Les builds WASM single-file de tesseract-core pèsent ~3,9 Mo pièce
#   (×3 variantes lstm) + la traineddata. On NE les met PAS dans git
#   (cf. .gitignore : public/vendor/tesseract/) — la cible prod est le
#   bucket anarbib-media-public/ocr/ (cadrage §2/§8). Ce script régénère
#   le dossier local pour `npm run dev`, de façon reproductible — à l'image
#   du install-pdfjs.sh documenté dans public/vendor/pdfjs/VERSION.
#
# Prérequis : `npm install` (tesseract.js + tesseract.js-core présents dans
# node_modules), curl, bash. À lancer depuis la racine du dépôt.
#
# Usage : scripts/install-tesseract.sh [LANGS...]
#   LANGS : codes traineddata à télécharger (défaut : por).
#           ex. scripts/install-tesseract.sh por fra spa
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/public/vendor/tesseract"
CORE="$ROOT/node_modules/tesseract.js-core"
LIB="$ROOT/node_modules/tesseract.js"
LANGS=("${@:-por}")

# Source des .traineddata.gz : modèles LSTM "best_int" (quantifiés, ~1,4 Mo/langue),
# cohérents avec lstmOnly=true côté worker. Même CDN que le défaut tesseract.js.
LANG_BASE="https://cdn.jsdelivr.net/npm/@tesseract.js-data"
LANG_VARIANT="4.0.0_best_int"

echo "▶ Vendorisation tesseract.js → $DEST"

if [ ! -d "$CORE" ] || [ ! -d "$LIB" ]; then
  echo "✗ node_modules/tesseract.js(-core) absent — lance d'abord: npm install" >&2
  exit 1
fi

mkdir -p "$DEST" "$DEST/lang"

# 1. Worker (glue chargé par la lib dans un Web Worker)
cp "$LIB/dist/worker.min.js" "$DEST/"
cp "$LIB/dist/worker.min.js.LICENSE.txt" "$DEST/" 2>/dev/null || true

# 2. Core WASM single-file (wasm embarqué base64 → un seul fichier à servir).
#    On vendorise les 3 variantes LSTM ; le navigateur choisit selon son
#    support (relaxed-SIMD → SIMD → scalaire) — cf. tesseract.js getCore.js.
for f in \
  tesseract-core-relaxedsimd-lstm.wasm.js \
  tesseract-core-simd-lstm.wasm.js \
  tesseract-core-lstm.wasm.js \
; do
  cp "$CORE/$f" "$DEST/"
done

# 3. Traineddata (modèles de langue), depuis le CDN tessdata.
for lang in "${LANGS[@]}"; do
  out="$DEST/lang/${lang}.traineddata.gz"
  url="$LANG_BASE/${lang}/${LANG_VARIANT}/${lang}.traineddata.gz"
  echo "  ↓ $lang : $url"
  curl -fsSL -o "$out" "$url"
done

# 4. Note de version (committée, elle ; les binaires non)
CORE_V="$(node -p "require('$CORE/package.json').version")"
LIB_V="$(node -p "require('$LIB/package.json').version")"
cat > "$DEST/VERSION" <<EOF
tesseract.js        : $LIB_V
tesseract.js-core   : $CORE_V
traineddata variant : $LANG_VARIANT
langues             : ${LANGS[*]}
Régénéré par        : scripts/install-tesseract.sh
Hébergement prod    : bucket anarbib-media-public/ocr/ (cadrage §2/§8) — P2/P3
EOF

echo "✓ Terminé. Servi à l'exécution depuis /vendor/tesseract/ (cf. ocrPipeline.js)."
ls -la "$DEST" "$DEST/lang"
