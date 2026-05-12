# ============================================================================
# apply-paquet24.ps1
#
# Orchestrateur d'application du paquet 24 :
#   - 24a : i18n SolicitarBibliotecaPage
#   - 24b : Cadastro -> Login
#   - 24c : Module identite visuelle dans onglet Identite + RLS Storage
#
# Hypotheses :
#   - Les fichiers livres sont dans C:\Users\accat\Downloads\paquet24\
#   - Le repo frontend est dans C:\Users\accat\Claude's AnarBib\anarbib-app\
#   - Le repo a un remote 'origin' configure avec dual-URL push (GitHub + Codeberg)
#   - Python 3 et npm sont dans le PATH
#
# Convention AnarBib :
#   - PowerShell N'EST PAS utilise pour lire/ecrire des fichiers a accents
#     (delegation systematique a Python avec encoding='utf-8')
#   - Messages git commit sans accents
#   - Migration DB poussee par push, applique par Woodpecker (PAS de SQL Editor)
#
# Usage :
#   .\apply-paquet24.ps1                  # execution complete
#   .\apply-paquet24.ps1 -DryRun          # affiche sans rien faire
#   .\apply-paquet24.ps1 -SkipBuild       # saute npm run build
#   .\apply-paquet24.ps1 -SkipPush        # saute le push (commit uniquement)
#   .\apply-paquet24.ps1 -SkipMigration   # saute la migration DB
# ============================================================================

[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$SkipBuild,
  [switch]$SkipPush,
  [switch]$SkipMigration
)

$ErrorActionPreference = 'Stop'

# --- Constantes (modifiables si chemins differents) ------------------------
$DOWNLOADS    = "C:\Users\accat\Downloads\paquet24"
$REPO_ROOT    = "C:\Users\accat\Claude's AnarBib\anarbib-app"
$BRANCH_EXPECTED = "main"

# Timestamp de la migration. Choisi superieur a la derniere migration appliquee
# en prod au 12/05/2026 (20260513160000 - paquetD8). Voir bilan v6 du backlog.
$MIGRATION_TS   = "20260514200000"
$MIGRATION_NAME = "paquet24c_storage_rls"

# --- Helpers ----------------------------------------------------------------
function Write-Step {
  param([string]$msg)
  Write-Host ""
  Write-Host "=============================================================" -ForegroundColor Cyan
  Write-Host " $msg" -ForegroundColor Cyan
  Write-Host "=============================================================" -ForegroundColor Cyan
}

function Write-Ok    { param([string]$msg) Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Skip  { param([string]$msg) Write-Host "[SKIP] $msg" -ForegroundColor Yellow }
function Write-Info  { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Gray }
function Write-Err   { param([string]$msg) Write-Host "[ERR]  $msg" -ForegroundColor Red }

# Git ecrit sur stderr meme en cas de succes — desactiver le traitement stderr=erreur
$PSNativeCommandUseErrorActionPreference = $false

function Test-CommandExists {
  param([string]$cmd)
  return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

# ============================================================================
# ETAPE 0 - Safety checks
# ============================================================================
Write-Step "Safety checks"

if (-not (Test-Path $DOWNLOADS)) {
  Write-Err "Dossier Downloads introuvable : $DOWNLOADS"
  Write-Err "Place les fichiers livres dans ce dossier avant de relancer."
  exit 1
}
Write-Ok "Dossier Downloads : $DOWNLOADS"

if (-not (Test-Path $REPO_ROOT)) {
  Write-Err "Repo frontend introuvable : $REPO_ROOT"
  exit 1
}
Write-Ok "Repo frontend     : $REPO_ROOT"

# Liste des fichiers attendus dans Downloads
$EXPECTED_FILES = @(
  "SolicitarBibliotecaPage.jsx",
  "LibraryVisualAssetsSection.jsx",
  "paquet24c-storage-rls.sql",
  "merge_i18n_paquet24.py",
  "patch_bibliotecapage.py"
)
$missing = @()
foreach ($f in $EXPECTED_FILES) {
  if (-not (Test-Path (Join-Path $DOWNLOADS $f))) {
    $missing += $f
  }
}
if ($missing.Count -gt 0) {
  Write-Err "Fichiers manquants dans Downloads :"
  $missing | ForEach-Object { Write-Err "  - $_" }
  exit 1
}
Write-Ok "Tous les fichiers livres sont presents (5/5)"

# Python ?
if (-not (Test-CommandExists "python")) {
  if (-not (Test-CommandExists "py")) {
    Write-Err "Python introuvable dans le PATH. Installer Python 3 ou utiliser py."
    exit 1
  } else {
    $script:PY = "py"
  }
} else {
  $script:PY = "python"
}
Write-Ok "Python : $script:PY"

# npm ?
if (-not $SkipBuild -and -not (Test-CommandExists "npm")) {
  Write-Err "npm introuvable dans le PATH. Installer Node.js ou utiliser -SkipBuild."
  exit 1
}

# Verifier branche git
Push-Location $REPO_ROOT
try {
  $branch = (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
  if ($LASTEXITCODE -ne 0) {
    Write-Err "Le repo n'est pas un depot git valide."
    exit 1
  }
  if ($branch -ne $BRANCH_EXPECTED) {
    Write-Err "Branche actuelle : '$branch'. Attendue : '$BRANCH_EXPECTED'."
    Write-Err "Bascule sur main avant de relancer (git checkout main)."
    exit 1
  }
  Write-Ok "Branche git : $branch"

  # Verifier que le repo est propre
  $status = git status --porcelain 2>$null
  if ($status) {
    Write-Err "Le repo a des modifications non commitees :"
    $status | ForEach-Object { Write-Err "  $_" }
    Write-Err ""
    Write-Err "Commit ou stash avant de relancer."
    exit 1
  }
  Write-Ok "Repo propre (working tree clean)"

  # Verifier les remotes
  $remotes = git remote get-url --all origin 2>$null
  if (-not $remotes) {
    Write-Err "Aucun remote 'origin' configure."
    exit 1
  }
  Write-Ok "Remotes 'origin' :"
  $remotes | ForEach-Object { Write-Info "  $_" }

  # Pull dernier etat
  Write-Info "git pull origin main..."
  if (-not $DryRun) {
    git pull origin main
    if ($LASTEXITCODE -ne 0) {
      Write-Err "git pull a echoue. Resoudre avant de relancer."
      exit 1
    }
  }
} finally {
  Pop-Location
}

if ($DryRun) {
  Write-Host ""
  Write-Host "==> Mode DRY-RUN : aucune modification ne sera appliquee." -ForegroundColor Magenta
  Write-Host ""
}

# ============================================================================
# ETAPE 1 - Copie SolicitarBibliotecaPage.jsx (paquet 24a + 24b)
# ============================================================================
Write-Step "Etape 1/6 : Copie SolicitarBibliotecaPage.jsx (paquets 24a + 24b)"

$src = Join-Path $DOWNLOADS "SolicitarBibliotecaPage.jsx"
$dst = Join-Path $REPO_ROOT "src\pages\public\SolicitarBibliotecaPage.jsx"

if (-not (Test-Path $dst)) {
  Write-Err "Cible introuvable : $dst"
  Write-Err "Verifier la structure du repo (le fichier original doit deja exister)."
  exit 1
}

if ($DryRun) {
  Write-Info "DRY-RUN : copierait $src -> $dst"
} else {
  # Copy-Item est binary-safe (preserve l'encoding UTF-8 du fichier source)
  Copy-Item -Path $src -Destination $dst -Force
  Write-Ok "Copie effectuee"
}

# ============================================================================
# ETAPE 2 - Copie LibraryVisualAssetsSection.jsx (paquet 24c composant)
# ============================================================================
Write-Step "Etape 2/6 : Copie LibraryVisualAssetsSection.jsx (paquet 24c)"

$src = Join-Path $DOWNLOADS "LibraryVisualAssetsSection.jsx"
$dstDir = Join-Path $REPO_ROOT "src\components\library"
$dst = Join-Path $dstDir "LibraryVisualAssetsSection.jsx"

if (-not (Test-Path $dstDir)) {
  Write-Err "Dossier cible introuvable : $dstDir"
  exit 1
}

if ($DryRun) {
  Write-Info "DRY-RUN : copierait $src -> $dst"
} else {
  Copy-Item -Path $src -Destination $dst -Force
  Write-Ok "Composant copie"
}

# ============================================================================
# ETAPE 3 - Copie migration SQL (paquet 24c DB)
# ============================================================================
Write-Step "Etape 3/6 : Copie migration SQL (paquet 24c)"

if ($SkipMigration) {
  Write-Skip "Migration SQL sautee (-SkipMigration)"
} else {
  $src = Join-Path $DOWNLOADS "paquet24c-storage-rls.sql"
  $migDir = Join-Path $REPO_ROOT "supabase\migrations"
  $migFile = "${MIGRATION_TS}_${MIGRATION_NAME}.sql"
  $dst = Join-Path $migDir $migFile

  if (-not (Test-Path $migDir)) {
    Write-Err "Dossier migrations introuvable : $migDir"
    exit 1
  }

  # Verifier qu'aucune migration avec un timestamp >= MIGRATION_TS n'existe deja
  # (sinon collision avec Supabase qui exige ordre strict)
  $futureMigrations = Get-ChildItem -Path $migDir -Filter "*.sql" |
    Where-Object { $_.Name -match "^(\d{14})_" } |
    Where-Object { $matches[1] -ge $MIGRATION_TS } |
    Select-Object -ExpandProperty Name
  if ($futureMigrations) {
    Write-Err "Une migration avec un timestamp >= $MIGRATION_TS existe deja :"
    $futureMigrations | ForEach-Object { Write-Err "  - $_" }
    Write-Err ""
    Write-Err "Editer le timestamp en tete de ce script (variable MIGRATION_TS)"
    Write-Err "vers une valeur strictement superieure, puis relancer."
    exit 1
  }

  if ($DryRun) {
    Write-Info "DRY-RUN : copierait $src -> $dst"
  } else {
    Copy-Item -Path $src -Destination $dst -Force
    Write-Ok "Migration copiee : $migFile"
    Write-Info "Sera appliquee par Woodpecker au push (supabase db push --linked --include-all)"
  }
}

# ============================================================================
# ETAPE 4 - Patch BibliotecaPage.jsx via Python (UTF-8 safe)
# ============================================================================
Write-Step "Etape 4/6 : Patch BibliotecaPage.jsx (Python UTF-8 safe)"

$patchScript = Join-Path $DOWNLOADS "patch_bibliotecapage.py"
$bibFile = Join-Path $REPO_ROOT "src\pages\biblioteca\BibliotecaPage.jsx"

if (-not (Test-Path $bibFile)) {
  Write-Err "BibliotecaPage.jsx introuvable : $bibFile"
  exit 1
}

$pyArgs = @($patchScript, "--file", $bibFile)
if ($DryRun) { $pyArgs += "--dry-run" }

Write-Info "$script:PY $($pyArgs -join ' ')"
& $script:PY @pyArgs
if ($LASTEXITCODE -ne 0) {
  Write-Err "patch_bibliotecapage.py a echoue (code $LASTEXITCODE)"
  exit 1
}
Write-Ok "Patch JSX applique"

# ============================================================================
# ETAPE 5 - Fusion i18n via Python (68 cles x 6 locales)
# ============================================================================
Write-Step "Etape 5/6 : Fusion i18n (68 cles x 6 locales)"

$mergeScript = Join-Path $DOWNLOADS "merge_i18n_paquet24.py"

$pyArgs = @($mergeScript, "--repo-root", $REPO_ROOT)
if ($DryRun) { $pyArgs += "--dry-run" }

Write-Info "$script:PY $($pyArgs -join ' ')"
& $script:PY @pyArgs
if ($LASTEXITCODE -ne 0) {
  Write-Err "merge_i18n_paquet24.py a echoue (code $LASTEXITCODE)"
  exit 1
}
Write-Ok "Fusion i18n appliquee"

# ============================================================================
# ETAPE 6 - Quality gate : npm run build
# ============================================================================
Write-Step "Etape 6/6 : Quality gate (npm run build)"

if ($SkipBuild) {
  Write-Skip "npm run build saute (-SkipBuild)"
} elseif ($DryRun) {
  Write-Info "DRY-RUN : lancerait 'npm run build' depuis $REPO_ROOT"
} else {
  Push-Location $REPO_ROOT
  try {
    Write-Info "npm run build (peut prendre 1-2 minutes)..."
    & npm run build
    if ($LASTEXITCODE -ne 0) {
      Write-Err "npm run build a echoue. Corriger avant commit."
      exit 1
    }
    Write-Ok "Build reussi"
  } finally {
    Pop-Location
  }
}

# ============================================================================
# ETAPE FINALE - Commit + Push
# ============================================================================
Write-Step "Commit + Push"

if ($DryRun) {
  Write-Info "DRY-RUN : sortie ici, aucun commit ne sera fait."
  Write-Host ""
  Write-Host "Pour appliquer reellement, relancer sans -DryRun." -ForegroundColor Magenta
  exit 0
}

Push-Location $REPO_ROOT
try {
  # Status avant commit
  Write-Info "git status :"
  git status --short | ForEach-Object { Write-Info "  $_" }

  # Add cible (limite aux fichiers du paquet pour ne pas embarquer autre chose)
  $filesToAdd = @(
    "src/pages/biblioteca/SolicitarBibliotecaPage.jsx",
    "src/pages/biblioteca/BibliotecaPage.jsx",
    "src/components/library/LibraryVisualAssetsSection.jsx"
  )

  # Locales : detecter le dossier reel
  $localeCandidates = @(
    "src/i18n/locales",
    "src/locales",
    "src/i18n",
    "public/locales",
    "i18n"
  )
  $localeDir = $null
  foreach ($c in $localeCandidates) {
    if (Test-Path (Join-Path $REPO_ROOT (Join-Path $c "pt-BR.json"))) {
      $localeDir = $c
      break
    }
  }
  if ($localeDir) {
    foreach ($loc in @("pt-BR", "fr", "es", "en", "it", "de")) {
      $filesToAdd += "$localeDir/$loc.json"
    }
    Write-Info "Locales detectees dans : $localeDir/"
  } else {
    Write-Err "Impossible de detecter le dossier locales. Verifier manuellement."
  }

  if (-not $SkipMigration) {
    $filesToAdd += "supabase/migrations/${MIGRATION_TS}_${MIGRATION_NAME}.sql"
  }

  Write-Info "git add :"
  foreach ($f in $filesToAdd) {
    $fullPath = Join-Path $REPO_ROOT $f
    if (Test-Path $fullPath) {
      git add -- $f
      Write-Info "  + $f"
    } else {
      Write-Skip "  ? $f (non present, ignore)"
    }
  }

  # Verifier qu'il y a au moins quelque chose a commiter
  $staged = git diff --cached --name-only
  if (-not $staged) {
    Write-Skip "Rien a commiter (le paquet a peut-etre deja ete applique)."
    exit 0
  }

  # Message commit SANS accents (convention AnarBib)
  $commitMsg = "paquet 24 : i18n SolicitarBibliotecaPage + module identite visuelle biblio"
  $commitBody = @"
- 24a : i18n complete de SolicitarBibliotecaPage, 47 cles x 6 locales
- 24b : remplacement semantique Cadastro -> Login dans la meme page
- 24c : module LibraryVisualAssetsSection dans l'onglet identite,
        upload des 5 fichiers de theme dans library-ui-assets/themes/{slug}/
        + 3 RLS Storage + RPC fn_ensure_library_theme,
        21 cles x 6 locales
"@

  Write-Info "git commit..."
  git commit -m $commitMsg -m $commitBody
  if ($LASTEXITCODE -ne 0) {
    Write-Err "git commit a echoue"
    exit 1
  }
  Write-Ok "Commit cree"

  if ($SkipPush) {
    Write-Skip "git push saute (-SkipPush)"
    Write-Info "Pour pousser plus tard : git push (poussera vers GitHub + Codeberg)"
  } else {
    Write-Info "git push (dual remote GitHub + Codeberg)..."
    git push
    if ($LASTEXITCODE -ne 0) {
      Write-Err "git push a echoue. Push manuel possible : 'git push'"
      exit 1
    }
    Write-Ok "Push reussi"
    Write-Host ""
    Write-Host "==> Woodpecker va appliquer :" -ForegroundColor Cyan
    Write-Host "    1. La migration SQL via 'supabase db push --linked --include-all'" -ForegroundColor Cyan
    Write-Host "    2. Le build frontend et le deploy Codeberg Pages" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    Suivre l'avancement : https://ci.codeberg.org/cclamazonia-cmd/AnarBib" -ForegroundColor Cyan
  }
} finally {
  Pop-Location
}

Write-Host ""
Write-Host "=============================================================" -ForegroundColor Green
Write-Host " Paquet 24 applique avec succes." -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Green
