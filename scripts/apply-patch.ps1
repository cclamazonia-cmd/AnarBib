# ============================================================================
# AnarBib -- apply-patch.ps1
# ============================================================================
# Applies a frontend patch in one command: .jsx files + locale additions
# + npm build + git commit + git push + GitHub Pages deploy.
#
# Usage:
#   .\scripts\apply-patch.ps1 -PatchDir "C:\path\to\patch-folder"
#
# The PatchDir must contain:
#   manifest.json          -- description + commit message
#   files/                 -- repo-relative tree of files to copy
#       src/pages/.../*.jsx
#   locale-additions/      -- optional, JSON files to merge into locales
#       pt-BR.json
#       fr.json
#       ...
#
# Options:
#   -SkipBuild       Do not run npm run build (fast but risky)
#   -SkipDeploy      Commit + push but do not deploy
#   -DryRun          Show what would be done, change nothing
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$PatchDir,

    [switch]$SkipBuild,
    [switch]$SkipDeploy,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$repoRoot = (Get-Location).Path

# Display helpers (ASCII only)
function Write-Step    { param($msg) Write-Host ">  $msg" -ForegroundColor Cyan }
function Write-Ok      { param($msg) Write-Host "OK $msg" -ForegroundColor Green }
function Write-Warn    { param($msg) Write-Host "!  $msg" -ForegroundColor Yellow }
function Write-Err     { param($msg) Write-Host "X  $msg" -ForegroundColor Red }
function Write-Info    { param($msg) Write-Host "   $msg" -ForegroundColor Gray }

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Magenta
Write-Host "  AnarBib -- Apply Patch" -ForegroundColor Magenta
Write-Host "===============================================================" -ForegroundColor Magenta
Write-Host ""

# ----------------------------------------------------------------------------
# STEP 1 -- Verify environment
# ----------------------------------------------------------------------------
Write-Step "Verifying environment"

if (-not (Test-Path $PatchDir)) {
    Write-Err "Patch directory not found: $PatchDir"
    exit 1
}
$PatchDir = (Resolve-Path $PatchDir).Path
Write-Info "PatchDir: $PatchDir"

$manifestPath = Join-Path $PatchDir "manifest.json"
if (-not (Test-Path $manifestPath)) {
    Write-Err "No manifest.json in $PatchDir"
    exit 1
}
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
Write-Ok  "Manifest read: $($manifest.title)"

if (-not (Test-Path ".git")) {
    Write-Err "Not in a git repo. Run from the AnarBib repo root."
    exit 1
}

$currentBranch = git rev-parse --abbrev-ref HEAD
if ($currentBranch -ne "main") {
    Write-Warn "You are on branch '$currentBranch' (not 'main')."
    $answer = Read-Host "Continue anyway? (y/N)"
    if ($answer -ne "y") { Write-Info "Aborted."; exit 0 }
}
Write-Ok  "Branch: $currentBranch"

$gitStatus = git status --porcelain
if ($gitStatus -and -not $DryRun) {
    Write-Warn "You have uncommitted changes:"
    git status --short
    Write-Host ""
    $answer = Read-Host "Continue anyway? Local changes will be mixed with the patch (y/N)"
    if ($answer -ne "y") { Write-Info "Aborted."; exit 0 }
}

Write-Host ""

# ----------------------------------------------------------------------------
# STEP 2 -- Show plan, ask confirmation
# ----------------------------------------------------------------------------
Write-Step "Application plan"
Write-Host ""
Write-Host "  Title:  $($manifest.title)" -ForegroundColor White
Write-Host "  Commit: $($manifest.commit_message)" -ForegroundColor White
Write-Host ""

$filesDir = Join-Path $PatchDir "files"
$jsxFiles = @()
if (Test-Path $filesDir) {
    $jsxFiles = Get-ChildItem -Path $filesDir -Recurse -File
    Write-Host "  Files to replace ($($jsxFiles.Count)):" -ForegroundColor White
    foreach ($f in $jsxFiles) {
        $rel = $f.FullName.Substring($filesDir.Length + 1).Replace('\', '/')
        Write-Info "    $rel"
    }
    Write-Host ""
}

$localeDir = Join-Path $PatchDir "locale-additions"
$localeFiles = @()
if (Test-Path $localeDir) {
    $localeFiles = Get-ChildItem -Path $localeDir -Filter "*.json" -File
    Write-Host "  Locales to update ($($localeFiles.Count)):" -ForegroundColor White
    foreach ($f in $localeFiles) {
        $patch = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $keyCount = ($patch.PSObject.Properties | Measure-Object).Count
        Write-Info "    $($f.Name) (+$keyCount keys)"
    }
    Write-Host ""
}

if ($DryRun) {
    Write-Warn "DryRun mode: nothing will be modified. Done."
    exit 0
}

$answer = Read-Host "Apply this patch? (Y/n)"
if ($answer -eq "n") { Write-Info "Aborted."; exit 0 }

Write-Host ""

# ----------------------------------------------------------------------------
# STEP 3 -- Snapshot existing files for rollback
# ----------------------------------------------------------------------------
Write-Step "Snapshot of current files (for possible rollback)"
$backupDir = Join-Path $env:TEMP "anarbib-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

$filesToBackup = @()
foreach ($f in $jsxFiles) {
    $rel = $f.FullName.Substring($filesDir.Length + 1)
    $target = Join-Path $repoRoot $rel
    if (Test-Path $target) {
        $backupTarget = Join-Path $backupDir $rel
        New-Item -ItemType Directory -Path (Split-Path $backupTarget -Parent) -Force | Out-Null
        Copy-Item $target $backupTarget
        $filesToBackup += @{ Source = $target; Backup = $backupTarget }
    }
}
foreach ($f in $localeFiles) {
    $target = Join-Path $repoRoot "src\i18n\locales\$($f.Name)"
    if (Test-Path $target) {
        $backupTarget = Join-Path $backupDir "src\i18n\locales\$($f.Name)"
        New-Item -ItemType Directory -Path (Split-Path $backupTarget -Parent) -Force | Out-Null
        Copy-Item $target $backupTarget
        $filesToBackup += @{ Source = $target; Backup = $backupTarget }
    }
}
Write-Ok "Backup saved to $backupDir"
Write-Host ""

function Invoke-Rollback {
    param($reason)
    Write-Err "ROLLBACK: $reason"
    foreach ($item in $filesToBackup) {
        Copy-Item $item.Backup $item.Source -Force
        Write-Info "  Restored: $($item.Source)"
    }
    Write-Warn "All files have been restored to their previous state."
    Write-Info "Backup still available at: $backupDir"
    exit 1
}

# ----------------------------------------------------------------------------
# STEP 4 -- Copy .jsx files
# ----------------------------------------------------------------------------
if ($jsxFiles.Count -gt 0) {
    Write-Step "Copying files"
    foreach ($f in $jsxFiles) {
        $rel = $f.FullName.Substring($filesDir.Length + 1)
        $target = Join-Path $repoRoot $rel
        $targetDir = Split-Path $target -Parent
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        Copy-Item $f.FullName $target -Force
        Write-Ok "  $rel"
    }
    Write-Host ""
}

# ----------------------------------------------------------------------------
# STEP 5 -- Merge locales preserving alphabetical key order
# ----------------------------------------------------------------------------
if ($localeFiles.Count -gt 0) {
    Write-Step "Merging locales"

    foreach ($f in $localeFiles) {
        $localeName = $f.Name
        $targetPath = Join-Path $repoRoot "src\i18n\locales\$localeName"

        if (-not (Test-Path $targetPath)) {
            Invoke-Rollback "Locale target not found: $targetPath"
        }

        $existingContent = Get-Content $targetPath -Raw -Encoding UTF8
        $existingHash = @{}

        try {
            $existing = $existingContent | ConvertFrom-Json
            $existing.PSObject.Properties | ForEach-Object {
                $existingHash[$_.Name] = $_.Value
            }
        } catch {
            Invoke-Rollback "Invalid JSON in $localeName : $_"
        }

        $patchContent = Get-Content $f.FullName -Raw -Encoding UTF8
        try {
            $patch = $patchContent | ConvertFrom-Json
        } catch {
            Invoke-Rollback "Invalid JSON in patch $($f.Name) : $_"
        }

        $addedKeys = @()
        $updatedKeys = @()
        $patch.PSObject.Properties | ForEach-Object {
            if ($existingHash.ContainsKey($_.Name)) {
                $updatedKeys += $_.Name
            } else {
                $addedKeys += $_.Name
            }
            $existingHash[$_.Name] = $_.Value
        }

        $sortedKeys = $existingHash.Keys | Sort-Object
        $merged = [ordered]@{}
        foreach ($k in $sortedKeys) {
            $merged[$k] = $existingHash[$k]
        }

        $json = $merged | ConvertTo-Json -Depth 10
        # Convert PowerShell's 4-space indent to 2-space (Prettier default)
        $lines = $json -split "`n"
        $newLines = @()
        foreach ($line in $lines) {
            if ($line -match '^( +)(.*)$') {
                $spaces = $matches[1].Length
                $rest = $matches[2]
                $newIndent = " " * ([int]($spaces / 2))
                $newLines += "$newIndent$rest"
            } else {
                $newLines += $line
            }
        }
        $json = $newLines -join "`n"

        try {
            $null = $json | ConvertFrom-Json
        } catch {
            Invoke-Rollback "Resulting JSON for $localeName is invalid: $_"
        }

        # Write UTF-8 without BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($targetPath, $json, $utf8NoBom)

        Write-Ok "  $localeName (+$($addedKeys.Count) added, $($updatedKeys.Count) updated)"
        if ($updatedKeys.Count -gt 0) {
            foreach ($k in $updatedKeys) {
                Write-Info "    [updated] $k (value overwritten)"
            }
        }
    }
    Write-Host ""
}

# ----------------------------------------------------------------------------
# STEP 6 -- npm run build (validate syntax)
# ----------------------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Step "Build verification (npm run build)"
    Write-Info "This usually takes 30-60 seconds..."

    $buildOutput = npm run build 2>&1
    $buildExitCode = $LASTEXITCODE

    if ($buildExitCode -ne 0) {
        Write-Host ""
        Write-Host $buildOutput
        Write-Host ""
        Invoke-Rollback "npm run build failed (exit code $buildExitCode). See output above."
    }

    Write-Ok "Build OK"
    Write-Host ""
} else {
    Write-Warn "Build skipped (-SkipBuild option)"
    Write-Host ""
}

# ----------------------------------------------------------------------------
# STEP 7 -- git add + commit + push
# ----------------------------------------------------------------------------
Write-Step "Commit and push"

git add -A
git commit -m $manifest.commit_message
if ($LASTEXITCODE -ne 0) {
    Invoke-Rollback "git commit failed"
}
Write-Ok "Commit created"

git push origin $currentBranch
if ($LASTEXITCODE -ne 0) {
    Write-Err "git push failed (but local commit exists). You can run 'git push' manually."
    exit 1
}
Write-Ok "Push done"
Write-Host ""

# ----------------------------------------------------------------------------
# STEP 8 -- Deploy GitHub Pages
# ----------------------------------------------------------------------------
if (-not $SkipDeploy) {
    Write-Step "Deploy GitHub Pages (npm run deploy)"

    $deployOutput = npm run deploy 2>&1
    $deployExitCode = $LASTEXITCODE

    if ($deployExitCode -ne 0) {
        Write-Host ""
        Write-Host $deployOutput
        Write-Err "npm run deploy failed. The commit is already pushed to main."
        Write-Info "You can run 'npm run deploy' manually."
        exit 1
    }
    Write-Ok "Deploy done"
} else {
    Write-Warn "Deploy skipped (-SkipDeploy option)"
}

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Green
Write-Host "  Patch applied successfully" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green
Write-Host ""
Write-Info "Backup kept at: $backupDir"
Write-Info "(You can delete it after verifying production.)"
Write-Host ""
