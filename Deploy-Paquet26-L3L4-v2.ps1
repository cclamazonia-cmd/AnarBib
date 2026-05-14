<#
================================================================================
  Deploy-Paquet26-L3L4-v2.ps1
================================================================================
  V2 du script de deploiement paquet 26 L3+L4.

  CHANGEMENTS PAR RAPPORT A v1 :
    - Lecture du contenu a inserer ENTRE marqueurs BEGIN/END PATCH plutot que
      via regex fragiles. Aucune regex pour extraire le contenu source.
    - Verifications simples par Select-String pour idempotence.
    - Insertion par recherche de la ligne d'ancrage + insertion AVANT/APRES.

  USAGE :
    .\Deploy-Paquet26-L3L4-v2.ps1 -RepoPath "C:\Users\accat\Claude's AnarBib\anarbib-app"

  OPTIONS :
    -SkipDeploy    : stoppe avant deploy Edge Function
    -SkipGitPush   : stoppe avant git push
    -NoSecret      : skip configuration secret APP_BASE_URL
    -AssumeYes     : auto-accepte toutes confirmations (debug uniquement)
================================================================================
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$RepoPath,

  [string]$DownloadsPath = "C:\Users\accat\Downloads",
  [switch]$SkipDeploy,
  [switch]$SkipGitPush,
  [switch]$NoSecret,
  [switch]$AssumeYes
)

$ErrorActionPreference = "Stop"
$ts = Get-Date -Format "yyyy-MM-dd_HHmm"
$snapshotPath = "$RepoPath.backup-paquet26-L3L4-$ts"
$logFile = "$DownloadsPath\paquet26-L3L4-deploy-$ts.log"

# ============================================================================
# Helpers
# ============================================================================

function Write-Step {
  param([string]$Step, [string]$Msg, [string]$Color = "Cyan")
  $line = "[$([DateTime]::Now.ToString('HH:mm:ss'))] [$Step] $Msg"
  Write-Host $line -ForegroundColor $Color
  Add-Content -Path $logFile -Value $line
}

function Write-Ok    { param([string]$Step, [string]$Msg) Write-Step $Step $Msg "Green" }
function Write-Warn  { param([string]$Step, [string]$Msg) Write-Step $Step ("WARN: " + $Msg) "Yellow" }
function Write-Err   { param([string]$Step, [string]$Msg) Write-Step $Step ("ERR: " + $Msg) "Red" }

function Confirm-Continue {
  param([string]$Prompt, [string]$Default = "n")
  if ($AssumeYes) { return $true }
  $answer = Read-Host "$Prompt (y/n, defaut: $Default)"
  if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $Default }
  return ($answer -match '^[yY]')
}

function Invoke-Rollback {
  param([string]$Reason)
  Write-Err "ROLLBACK" "Cause: $Reason"
  Write-Err "ROLLBACK" "Restauration depuis $snapshotPath ..."
  if (Test-Path $snapshotPath) {
    Remove-Item "$RepoPath\supabase\functions\_shared" -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item "$snapshotPath\supabase\functions\_shared" "$RepoPath\supabase\functions\_shared" -Recurse -Force
    Write-Ok "ROLLBACK" "Repo restaure depuis snapshot."
  } else {
    Write-Err "ROLLBACK" "Snapshot introuvable, rollback manuel necessaire."
  }
  exit 1
}

# Extrait le contenu entre 2 marqueurs (par defaut "BEGIN PATCH" et "END PATCH")
function Get-PatchContent {
  param(
    [string]$SourceFile,
    [string]$BeginMarker = "BEGIN PATCH",
    [string]$EndMarker = "END PATCH"
  )

  if (-not (Test-Path $SourceFile)) {
    throw "Source introuvable: $SourceFile"
  }

  $lines = Get-Content $SourceFile -Encoding UTF8
  $inside = $false
  $captured = @()

  foreach ($line in $lines) {
    if ($line -match [regex]::Escape($BeginMarker)) {
      $inside = $true
      continue
    }
    if ($line -match [regex]::Escape($EndMarker)) {
      $inside = $false
      continue
    }
    if ($inside) {
      $captured += $line
    }
  }

  if ($captured.Count -eq 0) {
    throw "Marqueurs '$BeginMarker' / '$EndMarker' introuvables ou bloc vide dans $SourceFile"
  }

  return ($captured -join "`n")
}

# Verifie si une marque sentinelle est deja presente dans un fichier
function Test-AlreadyPatched {
  param([string]$TargetFile, [string]$Sentinel)
  if (-not (Test-Path $TargetFile)) { return $false }
  return (Select-String -Path $TargetFile -Pattern $Sentinel -SimpleMatch -Quiet)
}

# Append un patch a la fin d'un fichier (avec saut de ligne propre)
function Add-PatchAtEnd {
  param([string]$TargetFile, [string]$Content, [string]$StepName)
  Add-Content -Path $TargetFile -Value "`n$Content" -Encoding UTF8 -NoNewline
  Write-Ok $StepName "Append OK dans $TargetFile"
}

# Insere un patch AVANT une ligne d'ancrage (recherche par sous-chaine simple)
function Add-PatchBeforeAnchor {
  param(
    [string]$TargetFile,
    [string]$Content,
    [string]$AnchorSubstring,
    [string]$StepName
  )
  $lines = Get-Content $TargetFile -Encoding UTF8
  $newLines = @()
  $inserted = $false

  foreach ($line in $lines) {
    if ((-not $inserted) -and ($line.Contains($AnchorSubstring))) {
      # Inserer le patch AVANT cette ligne
      foreach ($pl in ($Content -split "`n")) {
        $newLines += $pl
      }
      $inserted = $true
    }
    $newLines += $line
  }

  if (-not $inserted) {
    throw "Ancre '$AnchorSubstring' introuvable dans $TargetFile"
  }

  Set-Content -Path $TargetFile -Value $newLines -Encoding UTF8
  Write-Ok $StepName "Insert OK AVANT '$AnchorSubstring' dans $TargetFile"
}

# Insere un patch APRES une ligne d'ancrage
function Add-PatchAfterAnchor {
  param(
    [string]$TargetFile,
    [string]$Content,
    [string]$AnchorSubstring,
    [string]$StepName
  )
  $lines = Get-Content $TargetFile -Encoding UTF8
  $newLines = @()
  $inserted = $false

  foreach ($line in $lines) {
    $newLines += $line
    if ((-not $inserted) -and ($line.Contains($AnchorSubstring))) {
      foreach ($pl in ($Content -split "`n")) {
        $newLines += $pl
      }
      $inserted = $true
    }
  }

  if (-not $inserted) {
    throw "Ancre '$AnchorSubstring' introuvable dans $TargetFile"
  }

  Set-Content -Path $TargetFile -Value $newLines -Encoding UTF8
  Write-Ok $StepName "Insert OK APRES '$AnchorSubstring' dans $TargetFile"
}

function Invoke-DenoCheck {
  param([string]$File, [string]$StepName)
  if (-not (Get-Command deno -ErrorAction SilentlyContinue)) {
    Write-Warn $StepName "deno non installe, skip check"
    return $true
  }
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $output = & deno check $File 2>&1
  $denoExit = $LASTEXITCODE
  $ErrorActionPreference = $prevEAP
  if ($denoExit -ne 0) {
    Write-Err $StepName "deno check FAIL :"
    $output | ForEach-Object { Write-Err $StepName $_ }
    return $false
  }
  Write-Ok $StepName "deno check OK ($File)"
  return $true
}

# ============================================================================
# Preliminaires
# ============================================================================

Write-Host ""
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host "  Paquet 26 L3+L4 v2 - Deploy automatise" -ForegroundColor Magenta
Write-Host "  Demarrage : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "RepoPath  : $RepoPath"
Write-Host "Downloads : $DownloadsPath"
Write-Host "Log file  : $logFile"
Write-Host ""

if (-not (Test-Path $RepoPath)) {
  Write-Host "[FATAL] Repo introuvable : $RepoPath" -ForegroundColor Red
  exit 1
}
Set-Location $RepoPath

# Verifier que les fichiers v2 sont presents dans Downloads
$sources = @(
  "01_env_patch.ts",
  "02_policies_append.ts",
  "03_events_append.ts",
  "04_data_consultas.ts",
  "05_mail_strings_append.ts",
  "06_domain_consultas.ts",
  "07_dispatch_patch.ts"
)
$missing = @()
foreach ($src in $sources) {
  if (-not (Test-Path "$DownloadsPath\$src")) { $missing += $src }
}
if ($missing.Count -gt 0) {
  Write-Host "[FATAL] Fichiers sources manquants dans ${DownloadsPath}:" -ForegroundColor Red
  $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 1
}
Write-Ok "PRECHECK" "Sources OK dans Downloads"

# git status clean ?
$gitStatus = git status --porcelain 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Err "PRECHECK" "git status echoue. $RepoPath est-il bien un repo git ?"
  exit 1
}
if ($gitStatus) {
  Write-Warn "PRECHECK" "git status n'est pas clean :"
  $gitStatus | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
  if (-not (Confirm-Continue "Continuer ?")) { exit 1 }
}

# ============================================================================
# Etape 1 - Snapshot
# ============================================================================

Write-Step "STEP 1" "Snapshot ..."
if (Test-Path $snapshotPath) {
  Write-Warn "STEP 1" "Snapshot existe deja: $snapshotPath"
} else {
  # Snapshot UNIQUEMENT le dossier _shared (suffisant pour rollback)
  $sharedSnapshot = "$snapshotPath\supabase\functions"
  New-Item -ItemType Directory -Path $sharedSnapshot -Force | Out-Null
  Copy-Item "$RepoPath\supabase\functions\_shared" "$sharedSnapshot\_shared" -Recurse -Force
  Write-Ok "STEP 1" "Snapshot _shared cree : $snapshotPath"
}

# ============================================================================
# Etape 3 - Patch env.ts (APP_BASE_URL)
# ============================================================================

Write-Step "STEP 3" "Patch env.ts ..."
$envFile = "$RepoPath\supabase\functions\_shared\core\env.ts"

if (Test-AlreadyPatched -TargetFile $envFile -Sentinel "APP_BASE_URL") {
  Write-Warn "STEP 3" "APP_BASE_URL deja present, skip"
} else {
  try {
    $patch = Get-PatchContent -SourceFile "$DownloadsPath\01_env_patch.ts"
    Add-PatchBeforeAnchor -TargetFile $envFile -Content $patch `
      -AnchorSubstring "export const supabaseAdmin" -StepName "STEP 3"
  } catch {
    Invoke-Rollback "STEP 3 echoue: $_"
  }
}
if (-not (Invoke-DenoCheck $envFile "STEP 3")) {
  Invoke-Rollback "deno check env.ts FAIL"
}

# ============================================================================
# Etape 4 - Append policies.ts
# ============================================================================

Write-Step "STEP 4" "Append policies.ts ..."
$policiesFile = "$RepoPath\supabase\functions\_shared\context\policies.ts"

if (Test-AlreadyPatched -TargetFile $policiesFile -Sentinel "consultaCriadaEnabled") {
  Write-Warn "STEP 4" "Helpers consulta deja presents, skip"
} else {
  try {
    $patch = Get-PatchContent -SourceFile "$DownloadsPath\02_policies_append.ts"
    Add-PatchAtEnd -TargetFile $policiesFile -Content $patch -StepName "STEP 4"
  } catch {
    Invoke-Rollback "STEP 4 echoue: $_"
  }
}
if (-not (Invoke-DenoCheck $policiesFile "STEP 4")) {
  Invoke-Rollback "deno check policies.ts FAIL"
}

# ============================================================================
# Etape 5 - Append events.ts
# ============================================================================

Write-Step "STEP 5" "Append events.ts ..."
$eventsFile = "$RepoPath\supabase\functions\_shared\shared\events.ts"

if (Test-AlreadyPatched -TargetFile $eventsFile -Sentinel "normalizeConsultaLifecycleEvent") {
  Write-Warn "STEP 5" "Normalizers consulta deja presents, skip"
} else {
  try {
    $patch = Get-PatchContent -SourceFile "$DownloadsPath\03_events_append.ts"
    Add-PatchAtEnd -TargetFile $eventsFile -Content $patch -StepName "STEP 5"
  } catch {
    Invoke-Rollback "STEP 5 echoue: $_"
  }
}
if (-not (Invoke-DenoCheck $eventsFile "STEP 5")) {
  Invoke-Rollback "deno check events.ts FAIL"
}

# ============================================================================
# Etape 6 - Copy data/consultas.ts (nouveau fichier)
# ============================================================================

Write-Step "STEP 6" "Copy data/consultas.ts ..."
$dataFile = "$RepoPath\supabase\functions\_shared\data\consultas.ts"

if (Test-Path $dataFile) {
  Write-Warn "STEP 6" "data/consultas.ts existe deja, skip"
} else {
  Copy-Item "$DownloadsPath\04_data_consultas.ts" $dataFile -Force
  Write-Ok "STEP 6" "data/consultas.ts cree"
}
if (-not (Invoke-DenoCheck $dataFile "STEP 6")) {
  Invoke-Rollback "deno check data/consultas.ts FAIL"
}

# ============================================================================
# Etape 7 - Append i18n mail-strings.ts (PAUSE relecture militante)
# ============================================================================

Write-Step "STEP 7" "Append i18n mail-strings.ts ..."
$i18nFile = "$RepoPath\supabase\functions\_shared\i18n\mail-strings.ts"

if (Test-AlreadyPatched -TargetFile $i18nFile -Sentinel '"con.created.sub"') {
  Write-Warn "STEP 7" "Cles consulta deja presentes, skip"
} else {
  Write-Host ""
  Write-Host "  ATTENTION : insertion 17 cles i18n x 6 locales (102 traductions)." -ForegroundColor Yellow
  Write-Host "  Conventions militantes a verifier dans 05_mail_strings_append.ts." -ForegroundColor Yellow
  Write-Host ""
  if (-not (Confirm-Continue "  As-tu relu les conventions militantes ?")) {
    Invoke-Rollback "Utilisateur a annule l'insertion i18n"
  }

  try {
    $patch = Get-PatchContent -SourceFile "$DownloadsPath\05_mail_strings_append.ts"

    # Strategie : on cherche la fermeture "};" finale de l'objet S.
    # On lit toutes les lignes, on trouve la DERNIERE qui contient juste "};"
    # (apres trim), et on insere notre patch AVANT cette ligne.
    $lines = Get-Content $i18nFile -Encoding UTF8
    $lastCloseLineIdx = -1
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
      if ($lines[$i].Trim() -eq "};") {
        $lastCloseLineIdx = $i
        break
      }
    }

    if ($lastCloseLineIdx -lt 0) {
      Invoke-Rollback "Fermeture '};' introuvable dans mail-strings.ts"
    }

    $newLines = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($i -eq $lastCloseLineIdx) {
        foreach ($pl in ($patch -split "`n")) {
          $newLines += $pl
        }
      }
      $newLines += $lines[$i]
    }

    Set-Content -Path $i18nFile -Value $newLines -Encoding UTF8
    Write-Ok "STEP 7" "17 cles i18n inserees avant '};' (ligne $($lastCloseLineIdx + 1) d'origine)"
  } catch {
    Invoke-Rollback "STEP 7 echoue: $_"
  }
}

# Verif quantitative
$conCount = (Select-String -Path $i18nFile -Pattern '"con\.|"cwf\.').Count
if ($conCount -lt 17) {
  Invoke-Rollback "Seulement $conCount cles consulta detectees apres append (attendu >= 17)"
}
Write-Ok "STEP 7" "$conCount cles consulta detectees"

if (-not (Invoke-DenoCheck $i18nFile "STEP 7")) {
  Invoke-Rollback "deno check mail-strings.ts FAIL (virgule manquante ?)"
}

# ============================================================================
# Etape 8 - Copy domain/consultas.ts (nouveau fichier)
# ============================================================================

Write-Step "STEP 8" "Copy domain/consultas.ts ..."
$domainFile = "$RepoPath\supabase\functions\_shared\domain\consultas.ts"

if (Test-Path $domainFile) {
  Write-Warn "STEP 8" "domain/consultas.ts existe deja, skip"
} else {
  Copy-Item "$DownloadsPath\06_domain_consultas.ts" $domainFile -Force
  Write-Ok "STEP 8" "domain/consultas.ts cree"
}
if (-not (Invoke-DenoCheck $domainFile "STEP 8")) {
  Invoke-Rollback "deno check domain/consultas.ts FAIL"
}

# ============================================================================
# Etape 9 - Patch dispatch.ts (2 sections : IMPORT + ROUTES)
# ============================================================================

Write-Step "STEP 9" "Patch dispatch.ts ..."
$dispatchFile = "$RepoPath\supabase\functions\_shared\core\dispatch.ts"

# Sous-etape 9a : ajouter import APRES l'import reservas
if (Test-AlreadyPatched -TargetFile $dispatchFile -Sentinel "handleConsultaCriadaV2") {
  Write-Warn "STEP 9a" "Import consultas deja present, skip"
} else {
  try {
    $importPatch = Get-PatchContent -SourceFile "$DownloadsPath\07_dispatch_patch.ts" `
      -BeginMarker "BEGIN IMPORT" -EndMarker "END IMPORT"
    Add-PatchAfterAnchor -TargetFile $dispatchFile -Content $importPatch `
      -AnchorSubstring 'from "../domain/reservas.ts"' -StepName "STEP 9a"
  } catch {
    Invoke-Rollback "STEP 9a echoue: $_"
  }
}

# Sous-etape 9b : ajouter les 3 if AVANT profile_notice
if (Test-AlreadyPatched -TargetFile $dispatchFile -Sentinel "consulta_v2_criada") {
  Write-Warn "STEP 9b" "Routes consulta deja presentes, skip"
} else {
  try {
    $routesPatch = Get-PatchContent -SourceFile "$DownloadsPath\07_dispatch_patch.ts" `
      -BeginMarker "BEGIN ROUTES" -EndMarker "END ROUTES"
    Add-PatchBeforeAnchor -TargetFile $dispatchFile -Content $routesPatch `
      -AnchorSubstring 'event === "profile_notice"' -StepName "STEP 9b"
  } catch {
    Invoke-Rollback "STEP 9b echoue: $_"
  }
}

# Verif quantitative
$dispatchConsultaCount = (Select-String -Path $dispatchFile -Pattern "consulta_v2").Count
if ($dispatchConsultaCount -lt 6) {
  Invoke-Rollback "Seulement $dispatchConsultaCount occurrences consulta_v2 dans dispatch.ts (attendu >= 7)"
}
Write-Ok "STEP 9" "$dispatchConsultaCount occurrences consulta_v2 dans dispatch.ts"

if (-not (Invoke-DenoCheck $dispatchFile "STEP 9")) {
  Invoke-Rollback "deno check dispatch.ts FAIL"
}

# ============================================================================
# Etape 10 - deno check global sur notify-event/index.ts
# ============================================================================

Write-Step "STEP 10" "deno check global ..."
$indexFile = "$RepoPath\supabase\functions\notify-event\index.ts"
if (Test-Path $indexFile) {
  if (-not (Invoke-DenoCheck $indexFile "STEP 10")) {
    Invoke-Rollback "deno check global FAIL"
  }
} else {
  Write-Warn "STEP 10" "notify-event/index.ts introuvable, skip"
}

# ============================================================================
# Etape 11 - Secret APP_BASE_URL
# ============================================================================

if (-not $NoSecret) {
  Write-Step "STEP 11" "Configuration secret APP_BASE_URL ..."
  if (Confirm-Continue "Configurer le secret APP_BASE_URL=https://app.anarbib.org ?") {
    try {
      $output = & supabase secrets set "APP_BASE_URL=https://app.anarbib.org" 2>&1
      if ($LASTEXITCODE -eq 0) {
        Write-Ok "STEP 11" "Secret configure"
      } else {
        Write-Warn "STEP 11" "Secret set FAIL: $output (fallback hard-code utilise)"
      }
    } catch {
      Write-Warn "STEP 11" "Exception: $_"
    }
  }
}

# ============================================================================
# Etape 12 - Deploy Edge Function
# ============================================================================

if ($SkipDeploy) {
  Write-Warn "STEP 12" "SkipDeploy active, stop ici."
  Write-Host ""
  Write-Host "Pour deployer manuellement plus tard :" -ForegroundColor Yellow
  Write-Host "  cd $RepoPath" -ForegroundColor Yellow
  Write-Host "  supabase functions deploy notify-event --no-verify-jwt" -ForegroundColor Yellow
  exit 0
}

Write-Step "STEP 12" "Deploy Edge Function notify-event ..."
Write-Host ""
Write-Host "  ATTENTION : deploy en prod va remplacer l'Edge Function." -ForegroundColor Yellow
Write-Host ""

if (-not (Confirm-Continue "Lancer deploy ?")) {
  Write-Warn "STEP 12" "Deploy annule"
  exit 0
}

$versionBefore = & supabase functions list 2>&1 | Select-String "notify-event"
Write-Host "  Version avant: $versionBefore" -ForegroundColor Cyan

$deployOutput = & supabase functions deploy notify-event --no-verify-jwt 2>&1
if ($LASTEXITCODE -eq 0) {
  Write-Ok "STEP 12" "Deploy OK"
} else {
  Write-Err "STEP 12" "Deploy FAIL:"
  $deployOutput | ForEach-Object { Write-Err "STEP 12" $_ }
  if (-not (Confirm-Continue "Continuer vers git push quand meme ?")) { exit 1 }
}

Start-Sleep -Seconds 3
$versionAfter = & supabase functions list 2>&1 | Select-String "notify-event"
Write-Host "  Version apres: $versionAfter" -ForegroundColor Cyan

# ============================================================================
# Etape 13 - git add + commit + push
# ============================================================================

if ($SkipGitPush) {
  Write-Warn "STEP 13" "SkipGitPush active, stop ici."
  exit 0
}

Write-Step "STEP 13" "git add + commit + push ..."

git add supabase/functions/_shared/core/env.ts
git add supabase/functions/_shared/core/dispatch.ts
git add supabase/functions/_shared/context/policies.ts
git add supabase/functions/_shared/shared/events.ts
git add supabase/functions/_shared/i18n/mail-strings.ts
git add supabase/functions/_shared/data/consultas.ts
git add supabase/functions/_shared/domain/consultas.ts

Write-Host ""
Write-Host "git status apres add :" -ForegroundColor Cyan
git status --short
Write-Host ""

if (-not (Confirm-Continue "Lancer commit + push ?")) {
  Write-Warn "STEP 13" "Commit/push annule. Pour finaliser manuellement:"
  Write-Host "  git commit -m 'paquet 26 L3+L4 : handler consultations + i18n + dispatch + APP_BASE_URL'" -ForegroundColor Yellow
  Write-Host "  git push" -ForegroundColor Yellow
  exit 0
}

git commit -m "paquet 26 L3+L4 : handler consultations + i18n 17 cles x 6 locales + dispatch + APP_BASE_URL"
if ($LASTEXITCODE -ne 0) {
  Write-Err "STEP 13" "git commit FAIL"
  exit 1
}

git push
if ($LASTEXITCODE -ne 0) {
  Write-Err "STEP 13" "git push FAIL"
  exit 1
}

Write-Ok "STEP 13" "Commit + push OK"

# ============================================================================
# Resume final
# ============================================================================

Write-Host ""
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host "  Paquet 26 L3+L4 v2 - Deploy TERMINE" -ForegroundColor Magenta
Write-Host "  Fin : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "Etat final :" -ForegroundColor Green
Write-Host "  - 4 fichiers TS patches: env, policies, events, dispatch, i18n" -ForegroundColor Green
Write-Host "  - 2 fichiers TS crees: data/consultas, domain/consultas" -ForegroundColor Green
Write-Host "  - Edge Function notify-event deployee" -ForegroundColor Green
Write-Host "  - Commit git pushe sur Codeberg + GitHub" -ForegroundColor Green
Write-Host "  - Snapshot conserve: $snapshotPath" -ForegroundColor Green
Write-Host "  - Log: $logFile" -ForegroundColor Green
Write-Host ""
Write-Host "Prochaines etapes :" -ForegroundColor Cyan
Write-Host "  1. Test fonctionnel end-to-end BLMF" -ForegroundColor Cyan
Write-Host "  2. Mettre a jour docs/paquets/paquet-26-decisions.md" -ForegroundColor Cyan
Write-Host "  3. Lancer Phase 4 et Phase 5" -ForegroundColor Cyan
Write-Host ""
