#!/usr/bin/env pwsh
# =========================================================================
# Hook git pre-commit AnarBib - Verification doctrine creation objets
# =========================================================================
# Ce hook scanne les fichiers .sql stages et refuse le commit si des
# patterns a risque sont detectes sans les contreparties doctrinales.
#
# Doctrine de reference :
#   docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md
#
# Bypass legitime (par exemple paquet L.11 qui documente sciemment une
# vue SECURITY DEFINER) :
#   git commit --no-verify -m "..."
#
# INSTALLATION (a faire une seule fois) :
#   1. Copier ce fichier vers .git/hooks/pre-commit (sans extension)
#   2. Si Unix : chmod +x .git/hooks/pre-commit
#   3. Sur Windows avec git Bash : git config core.hooksPath .githooks
#      et placer le fichier dans .githooks/pre-commit (recommande pour
#      pouvoir le versionner)
# =========================================================================

$ErrorActionPreference = "Stop"

# Recuperer les fichiers .sql modifies ou ajoutes et stages
$stagedSqlFiles = git diff --cached --name-only --diff-filter=AM | Where-Object { $_ -like "*.sql" }

if (-not $stagedSqlFiles) {
    # Pas de fichier SQL stage, rien a verifier
    exit 0
}

Write-Host ""
Write-Host "[Hook pre-commit AnarBib] Verification doctrine SQL..." -ForegroundColor Cyan
Write-Host ""

$violations = @()

foreach ($file in $stagedSqlFiles) {
    # Ignorer le template lui-meme (qui contient les patterns a demontrer)
    if ($file -match "_TEMPLATE\.sql$") {
        continue
    }

    # Ignorer les fichiers d'audit qui peuvent legitimement deroger
    if ($file -match "paquetL3_audit") {
        continue
    }

    # Lire le contenu du fichier stage (pas la version disque, qui peut differer)
    $content = git show ":$file" 2>$null
    if (-not $content) { continue }

    $contentJoined = $content -join "`n"

    # Retirer les commentaires SQL avant analyse (faux positifs #80) : un
    # mot-cle comme SECURITY DEFINER dans un commentaire ne doit pas bloquer.
    $scan = $contentJoined -replace '(?s)/\*.*?\*/', ' '
    $scan = $scan -replace '(?m)--.*$', ''

    # ---- Test 1 : SECURITY DEFINER sans SET search_path -----------------
    if ($scan -match "(?i)SECURITY\s+DEFINER" -and
        $scan -notmatch "(?i)SET\s+search_path") {
        $violations += @{
            File   = $file
            Rule   = "SECURITY DEFINER sans SET search_path"
            Detail = "Toute fonction SECURITY DEFINER DOIT inclure SET search_path = public, pg_catalog"
            Doc    = "Template 1 - Section 'Points doctrinaux'"
        }
    }

    # ---- Test 2 : SECURITY DEFINER sans REVOKE EXECUTE FROM PUBLIC ------
    # #80 : on n'exige le REVOKE que pour les fonctions CREEES (CREATE FUNCTION).
    # Les CREATE OR REPLACE preservent les grants/REVOKE deja en DB -> exemptees
    # (c'etait l'intention du commentaire d'origine, jamais codee).
    if ($scan -match "(?i)CREATE\s+FUNCTION[^;]+SECURITY\s+DEFINER" -and
        $scan -notmatch "(?i)REVOKE\s+EXECUTE.+FROM\s+PUBLIC") {
        $violations += @{
            File   = $file
            Rule   = "SECURITY DEFINER sans REVOKE EXECUTE FROM PUBLIC"
            Detail = "Toute nouvelle fonction SECURITY DEFINER DOIT inclure REVOKE EXECUTE FROM PUBLIC suivi de GRANT TO <role cible>"
            Doc    = "Template 1 - Bloc complet"
        }
    }

    # ---- Test 3 : CREATE TABLE public.* sans ENABLE ROW LEVEL SECURITY --
    # On regarde uniquement les CREATE TABLE dans le schema public
    if ($scan -match "(?im)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?public\.\w+" -and
        $scan -notmatch "(?i)ENABLE\s+ROW\s+LEVEL\s+SECURITY") {
        $violations += @{
            File   = $file
            Rule   = "CREATE TABLE public sans ENABLE ROW LEVEL SECURITY"
            Detail = "Toute nouvelle table dans public DOIT activer la RLS et avoir au moins une policy"
            Doc    = "Template 2 - Bloc complet"
        }
    }

    # ---- Test 4 : CREATE VIEW sans security_invoker ---------------------
    # On regarde les CREATE VIEW (pas les materialized views, qui ne
    # supportent pas security_invoker)
    if ($scan -match "(?im)CREATE\s+(?:OR\s+REPLACE\s+)?VIEW\s+(?!.*MATERIALIZED)" -and
        $scan -notmatch "(?i)security_invoker\s*=\s*true") {
        $violations += @{
            File   = $file
            Rule   = "CREATE VIEW sans security_invoker = true"
            Detail = "Toute nouvelle vue DOIT inclure WITH (security_invoker = true), sauf doctrine politique explicite"
            Doc    = "Template 3 - Section 'Points doctrinaux'"
        }
    }

    # ---- Test 5 : CREATE TABLE public sans GRANT explicite --------------
    # Test a faible bruit : on cherche juste la presence d'au moins UN GRANT
    # sur la table creee
    if ($scan -match "(?im)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?public\.(\w+)") {
        $tableName = $Matches[1]
        if ($scan -notmatch "(?im)GRANT\s+\w+.*ON\s+(?:TABLE\s+)?public\.$tableName\s+TO") {
            $violations += @{
                File   = $file
                Rule   = "CREATE TABLE public.$tableName sans GRANT explicite"
                Detail = "Conformite Supabase 30/10/2026 : toute nouvelle table DOIT inclure GRANT explicites pour les roles legitimes"
                Doc    = "Template 2 - Section 'Points doctrinaux'"
            }
        }
    }
}

# Resume
if ($violations.Count -eq 0) {
    Write-Host "[OK] Aucune violation doctrinale detectee dans les $($stagedSqlFiles.Count) fichier(s) SQL stage(s)." -ForegroundColor Green
    Write-Host ""
    exit 0
}

Write-Host "[BLOQUE] $($violations.Count) violation(s) doctrinale(s) detectee(s) :" -ForegroundColor Red
Write-Host ""

$i = 1
foreach ($v in $violations) {
    Write-Host "  $i. $($v.File)" -ForegroundColor Yellow
    Write-Host "     Regle  : $($v.Rule)" -ForegroundColor White
    Write-Host "     Detail : $($v.Detail)" -ForegroundColor Gray
    Write-Host "     Voir   : docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md ($($v.Doc))" -ForegroundColor Gray
    Write-Host ""
    $i++
}

Write-Host "Pour bypass un cas legitimement deroge (doctrine politique explicite) :" -ForegroundColor Cyan
Write-Host "  git commit --no-verify -m `"...`"" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sinon, corriger les violations dans les fichiers concernes et re-stager." -ForegroundColor Cyan
Write-Host ""

exit 1
