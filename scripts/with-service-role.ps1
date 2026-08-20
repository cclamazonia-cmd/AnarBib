<#
.SYNOPSIS
  Lance un script Node qui exige la cle service_role, SANS que la cle passe
  jamais par une ligne de commande.

.DESCRIPTION
  Pourquoi ce fichier. La consigne usuelle etait :

      SUPABASE_SERVICE_ROLE_KEY=eyJ... node scripts/xxx.mjs

  Elle a deux defauts, l'un benin et l'autre pas. Benin : cette syntaxe est
  celle de bash, elle n'existe pas en PowerShell. Pas benin : la cle finit
  ecrite EN CLAIR dans l'historique PowerShell
  (%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt),
  ou elle reste indefiniment. Vecu le 20/08/2026.

  Ici, la cle est demandee a une invite masquee. Ce qui est saisi a une invite
  n'entre PAS dans l'historique des commandes. Elle vit dans une variable
  d'environnement le temps du script, puis est effacee, y compris si le script
  echoue ou si tu l'interromps.

.PARAMETER Script
  Chemin du script Node a lancer (relatif a la racine du depot, ou absolu).

.PARAMETER Args
  Arguments passes tels quels au script (ex. --dry-run).

.EXAMPLE
  .\scripts\with-service-role.ps1 scripts\upload-anarbib-logo.mjs --dry-run

.EXAMPLE
  .\scripts\with-service-role.ps1 scripts\move-restricted-pdf-to-private-bucket.mjs

.NOTES
  Ne resout PAS l'historique du presse-papiers : si tu COLLES la cle et que
  Win+V est actif, elle y reste. Le script propose de le vider a la fin.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Script,

  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$ErrorActionPreference = 'Stop'

# Racine du depot = dossier parent de scripts/
$racine = Split-Path -Parent $PSScriptRoot
$cible = if ([System.IO.Path]::IsPathRooted($Script)) { $Script } else { Join-Path $racine $Script }

if (-not (Test-Path -LiteralPath $cible)) {
  Write-Host "X Script introuvable : $cible" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "  Script  : $cible"
if ($Args) { Write-Host "  Options : $($Args -join ' ')" }
Write-Host ""
Write-Host "  Colle la cle service_role puis Entree. Rien ne s'affichera," -ForegroundColor Cyan
Write-Host "  et elle n'entrera pas dans l'historique des commandes." -ForegroundColor Cyan
Write-Host ""

$secure = Read-Host -Prompt '  Cle service_role' -AsSecureString
if (-not $secure -or $secure.Length -eq 0) {
  Write-Host "X Aucune cle saisie. Rien n'a ete lance." -ForegroundColor Red
  exit 1
}

$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  $cle = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

# Controle de forme AVANT de lancer quoi que ce soit : attraper une cle tronquee
# ou la mauvaise cle (l'anon commence pareil mais porte un role different) coute
# moins cher qu'un script qui echoue a mi-chemin. On ne montre jamais la valeur.
$estJwt = $cle -match '^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$'
$estSecret = $cle -match '^sb_secret_[A-Za-z0-9_-]{10,}$'
if (-not ($estJwt -or $estSecret)) {
  Write-Host "X Ca ne ressemble ni a un JWT (eyJ....) ni a une cle sb_secret_." -ForegroundColor Red
  Write-Host "  Longueur lue : $($cle.Length) caracteres. Copie incomplete ?" -ForegroundColor Red
  $cle = $null
  exit 1
}
if ($estJwt) {
  # Le corps du JWT porte le role. On refuse poliment une cle anon.
  $corps = $cle.Split('.')[1].Replace('-', '+').Replace('_', '/')
  while ($corps.Length % 4) { $corps += '=' }
  try {
    $charge = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($corps)) | ConvertFrom-Json
    if ($charge.role -and $charge.role -ne 'service_role') {
      Write-Host "X Cette cle porte le role '$($charge.role)', pas 'service_role'." -ForegroundColor Red
      Write-Host "  C'est probablement la cle anon. Rien n'a ete lance." -ForegroundColor Red
      $cle = $null
      exit 1
    }
  } catch {
    Write-Host "! Role illisible dans le jeton ; on continue quand meme." -ForegroundColor Yellow
  }
}

$code = 1
try {
  $env:SUPABASE_SERVICE_ROLE_KEY = $cle
  $cle = $null
  Write-Host ""
  Push-Location $racine
  try {
    & node $cible @Args
    $code = $LASTEXITCODE
  } finally {
    Pop-Location
  }
} finally {
  # Efface la cle QUOI QU'IL ARRIVE : erreur, Ctrl+C, exception.
  $env:SUPABASE_SERVICE_ROLE_KEY = $null
  Remove-Item Env:\SUPABASE_SERVICE_ROLE_KEY -ErrorAction SilentlyContinue
  [GC]::Collect()
  Write-Host ""
  Write-Host "  Cle effacee de la session." -ForegroundColor Green
}

# L'invite masquee protege l'historique des commandes, pas le presse-papiers :
# si tu as COLLE la cle et que Win+V est actif, elle y figure encore.
try {
  Set-Clipboard -Value '' -ErrorAction Stop
  Write-Host "  Presse-papiers vide." -ForegroundColor Green
  Write-Host "  (Win+V garde un historique separe : videz-le depuis Win+V si actif.)" -ForegroundColor DarkGray
} catch {
  Write-Host "! Presse-papiers non vide automatiquement — fais-le a la main." -ForegroundColor Yellow
}

exit $code
