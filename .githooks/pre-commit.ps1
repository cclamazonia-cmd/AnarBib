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
$stagedAll     = git diff --cached --name-only --diff-filter=AM
$stagedSqlFiles = $stagedAll | Where-Object { $_ -like "*.sql" }

# Regle 6 : tout ce qui est stage sous tests/sql/, quelle que soit l'extension.
# Le README y compte autant que les suites : c'est lui qui, jusqu'au 29/08/2026,
# donnait la table de correspondance entre des prenoms et des identifiants de
# comptes releves en production.
$stagedTestFiles = $stagedAll | Where-Object { $_ -replace "\\", "/" -like "tests/sql/*" }

# Regle 7 : les migrations stagees, pour la collision d'horodatage.
# La convention de format (horodatage a la seconde) ne s'applique qu'aux
# migrations AJOUTEES : retoucher le commentaire d'une vieille migration ne
# doit pas obliger a la renommer -- et la renommer la ferait rejouer.
$addedAll = git diff --cached --name-only --diff-filter=A
$stagedMigrations = $stagedAll | Where-Object {
    ($_ -replace "\\", "/") -like "supabase/migrations/*" -and $_ -like "*.sql"
}

if (-not $stagedSqlFiles -and -not $stagedTestFiles -and -not $stagedMigrations) {
    # Rien de pertinent stage, rien a verifier
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
    # Le search_path peut etre ecrit sous la forme citee -- SET "search_path" TO
    # 'public', 'ingest' -- c'est celle que rend pg_get_functiondef, donc celle
    # que portent tous les corps EXTRAITS du baseline (doctrine du depot : on
    # n'y retape jamais une fonction). Sans le "? optionnel, ces corps etaient
    # signales alors que leur search_path est bel et bien epingle. Faux positif
    # constate le 28/08/2026 sur chemin_oai_pmh_executable et aligner_le_bouton.
    # Faux positif n.3, constate le 30/08/2026 : le scan retire les commentaires
    # `--` mais PAS les chaines de caracteres. « SECURITY DEFINER » ecrit dans un
    # COMMENT ON FUNCTION ou dans un libelle de test declenchait la regle sur des
    # fichiers qui ne CREENT aucune fonction -- une migration de REVOKE, une suite
    # de tests. On ajoute donc la premisse de la doctrine : la regle ne s'applique
    # qu'a un fichier qui cree ou modifie une fonction. On ne retire pas les
    # chaines du scan, exprès : une fonction creee en SQL dynamique vit dans une
    # chaine, et celle-la doit rester attrapee.
    $cree_une_fonction = $scan -match "(?i)(CREATE\s+(OR\s+REPLACE\s+)?FUNCTION|ALTER\s+FUNCTION)"
    if ($cree_une_fonction -and
        $scan -match "(?i)SECURITY\s+DEFINER" -and
        $scan -notmatch '(?i)SET\s+"?search_path"?') {
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

    # ---- Test 3 : CREATE TABLE public/ingest sans ENABLE ROW LEVEL SECURITY --
    # `ingest` ajoute le 29/08/2026 (paquet INGEST-RLS) : huit de ses tables
    # etaient nees sans RLS, precisement parce que cette regle ne regardait que
    # `public`. Dans `ingest` la RLS n'attend pas de policy - le schema n'est
    # expose a personne et les fonctions d'import passent par le proprietaire.
    # Les tables d'essai des suites de test (prefixe __) sont hors regle : elles
    # naissent et meurent dans la meme transaction.
    if ($scan -match "(?im)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:public|ingest)\.(?!__)\w+" -and
        $scan -notmatch "(?i)ENABLE\s+ROW\s+LEVEL\s+SECURITY") {
        $violations += @{
            File   = $file
            Rule   = "CREATE TABLE public/ingest sans ENABLE ROW LEVEL SECURITY"
            Detail = "Toute nouvelle table dans public DOIT activer la RLS et avoir au moins une policy ; dans ingest, la RLS seule suffit"
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
    if ($scan -match "(?im)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?public\.(?!__)(\w+)") {
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

# =========================================================================
# ---- Test 6 : identifiants de production dans tests/sql/ ----------------
# =========================================================================
# Ajoute le 29/08/2026 (backlog v34, item I14).
#
# POURQUOI. Trois suites designaient leurs acteurs par des UUID releves dans
# la base REELLE le 11/05/2026 -- trois des quatre correspondaient a des
# comptes existants -- et tests/sql/README.md les presentait comme des
# personas nommees. Les prenoms etaient fictifs : c'est precisement le piege.
# Une etiquette inventee sur une ligne reelle eteint la vigilance au lieu de
# l'appeler. Les suites tournent en BEGIN/ROLLBACK sur une base jetable, donc
# rien n'est arrive, mais la convention qui rendait cela sur n'etait ecrite
# nulle part. Cette regle la rend mecanique.
#
# COMMENT. La liste blanche n'est pas recopiee ici : elle est LUE dans
# supabase/seed.sql. Un acteur de test se demande au seed ; s'il n'y est pas,
# il n'a rien a faire dans une suite. Sont tolerees en plus les valeurs
# visiblement synthetiques -- celles dont les 32 chiffres hexadecimaux
# n'utilisent pas plus de 8 caracteres distincts (11111111-..., ccccddaa-...),
# ce qui laisse chaque suite forger ses propres fixtures dans sa transaction.
# Un UUID d'apparence aleatoire, lui, ressemble a un identifiant de production
# et doit se justifier.
$uuidRe = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

if ($stagedTestFiles) {
    $seedUuids = @()
    if (Test-Path "supabase/seed.sql") {
        $seedTxt = Get-Content "supabase/seed.sql" -Raw
        $seedUuids = [regex]::Matches($seedTxt, $uuidRe) | ForEach-Object { $_.Value.ToLower() }
    }

    foreach ($file in $stagedTestFiles) {
        $content = git show ":$file" 2>$null
        if (-not $content) { continue }
        $txt = $content -join "`n"

        $suspects = [regex]::Matches($txt, $uuidRe) |
            ForEach-Object { $_.Value.ToLower() } |
            Sort-Object -Unique |
            Where-Object {
                $u = $_
                if ($seedUuids -contains $u) { return $false }
                $hex = $u -replace '-', ''
                # "visiblement synthetique" : peu de caracteres distincts
                $distincts = ($hex.ToCharArray() | Sort-Object -Unique).Count
                return ($distincts -gt 8)
            }

        if ($suspects) {
            $violations += @{
                File   = $file
                Rule   = "UUID d'apparence reelle dans tests/sql : $($suspects -join ', ')"
                Detail = "Un acteur de test se demande au seed (supabase/seed.sql), il ne se preleve pas en base. Une fixture relevee en production reste une donnee de production. Si cet identifiant est bien synthetique, ajoutez-le au seed ; s'il designe une ligne reelle, ce fichier n'est pas une suite de tests et n'a pas sa place ici."
                Doc    = "backlog v34 item I14 - tests/sql/README.md"
            }
        }
    }
}

# =========================================================================
# ---- Test 7 : collision d'horodatage entre migrations ------------------
# =========================================================================
# Ajoute le 30/08/2026, le jour ou le cas s'est produit.
#
# POURQUOI. Une migration a ete horodatee 20260830090000 alors que ce prefixe
# etait deja pris. Deux symptomes, une seule cause, et aucun des deux ne
# s'annonce :
#   * en production, `supabase db push` indexe par VERSION -- voyant le
#     numero deja inscrit a schema_migrations, il a saute le fichier SANS
#     RIEN DIRE. Deploiement vert, migration jamais executee ;
#   * en CI, ou tout est rejoue depuis zero dans l'ordre des noms de
#     fichiers, l'ordre alphabetique a place la nouvelle migration AVANT
#     celle dont elle dependait.
#
# Une collision de version est donc pire qu'une erreur : c'est un succes
# apparent. Elle ne coute rien a detecter -- le prefixe suffit.
# DOC-DEPLOY-1 : migrations horodatees UTC, verifier avant de choisir.
if ($stagedMigrations) {
    # Les versions deja presentes au depot, hors fichiers en cours d'ajout.
    $existantes = @{}
    if (Test-Path "supabase/migrations") {
        Get-ChildItem "supabase/migrations" -Filter "*.sql" -File | ForEach-Object {
            if ($_.Name -match '^(\d{14})_') {
                $v = $Matches[1]
                if (-not $existantes.ContainsKey($v)) { $existantes[$v] = @() }
                $existantes[$v] += $_.Name
            }
        }
    }

    foreach ($file in $stagedMigrations) {
        $nom = Split-Path $file -Leaf
        # Les fichiers prefixes par _ ne sont pas des migrations : le gabarit
        # (_TEMPLATE.sql) et les scripts de retour arriere (_rollback_*.sql),
        # qui portent en NOM la version qu'ils annulent et ne doivent surtout
        # pas etre horodates comme une migration -- ils seraient rejoues.
        if ($nom -like "_*") { continue }
        if ($nom -notmatch '^(\d{14})_') {
            $violations += @{
                File   = $file
                Rule   = "Migration sans horodatage a 14 chiffres"
                Detail = "Le nom doit commencer par AAAAMMJJHHMMSS_ (UTC). C'est ce prefixe qui ordonne la sequence en CI et qui identifie la migration en production."
                Doc    = "DOC-DEPLOY-1"
            }
            continue
        }
        $version = $Matches[1]

        # ---- Horodatage a la seconde reelle, pas a l'heure ronde ---------
        # Ajoute le 30/08/2026, sur la remarque de Xavier -- et c'est une
        # meilleure parade que la detection de collision elle-meme : une
        # collision se DETECTE, une convention l'EMPECHE.
        # Le depot portait les deux usages : 154 migrations a la seconde
        # (l'usage d'origine) et 70 a l'heure ronde. L'habitude des heures
        # rondes s'est installee en aout, et elle revient a choisir a la main
        # dans un jeu de douze creneaux par jour, de memoire. C'est exactement
        # ce qui a produit la collision du 30/08.
        # Ne s'applique qu'aux migrations AJOUTEES.
        if ($addedAll -contains $file -and $version -match '0000$') {
            $violations += @{
                File   = $file
                Rule   = "Horodatage a l'heure ronde ($version)"
                Detail = "Prendre l'heure UTC reelle, a la seconde : (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss'). Une heure ronde revient a choisir de memoire dans douze creneaux par jour -- c'est ainsi qu'on se retrouve a deux sur le meme numero, et supabase db push saute alors le fichier sans rien dire."
                Doc    = "DOC-DEPLOY-4"
            }
        }

        $homonymes = @($existantes[$version] | Where-Object { $_ -ne $nom })
        if ($homonymes.Count -gt 0) {
            $violations += @{
                File   = $file
                Rule   = "Horodatage $version deja pris par $($homonymes -join ', ')"
                Detail = "supabase db push indexe par version : il sauterait ce fichier SANS ERREUR -- deploiement vert, migration jamais executee. Et en CI l'ordre alphabetique deciderait laquelle passe en premier. Choisir un horodatage libre, posterieur au dernier utilise."
                Doc    = "DOC-DEPLOY-1 - backlog v34"
            }
        }
    }
}

# Resume
if ($violations.Count -eq 0) {
    Write-Host "[OK] Aucune violation doctrinale detectee ($($stagedSqlFiles.Count) fichier(s) SQL, $($stagedTestFiles.Count) de tests, $($stagedMigrations.Count) migration(s))." -ForegroundColor Green
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
