# RUNBOOK — Retrait de `test.anarbib.org`

**23/10/2026.** Décision de Xavier, prise au cadrage de la phase 2 des tests d'intrusion :
`test.anarbib.org` n'est pas une copie de test. C'est le front téléversé par l'action
git-pages lors de l'essai de bascule du 20/08 (« étape 0 » de la migration git-pages, voir le
commentaire de `.forgejo/workflows/ci.yml` au pas « Deploy Pages »), resté en ligne depuis,
**branché sur la base de production** `uflwmikiyjfnikiphtcp`. Aucune branche ne le porte : il
n'existe que sur le serveur git-pages de Codeberg.

## Ce qui a été relevé (lecture seule, 23/10/2026)

| Point | Constat |
|---|---|
| Contenu servi | `server: git-pages`, `last-modified: Fri, 21 Aug 2026 14:04:44 GMT`, bundle `assets/index-DGmoP40U.js`, `sw.js` enregistré (service worker) |
| Base appelée | `uflwmikiyjfnikiphtcp.supabase.co`, avec l'**ancienne clé `anon` JWT** |
| Cette clé | **désactivée** côté prod (clés « legacy » coupées) : toute requête du vieux front reçoit **401** (`rest/v1`, `auth/v1/settings` essayés). Le site est donc une coquille inerte — mais aux couleurs d'AnarBib, sous notre domaine, et qui se rallumerait si les clés héritées étaient un jour réactivées. |
| DNS, à l'autorité (`dns14.ovh.net`) | `test.anarbib.org CNAME codeberg.page.` ; `_git-pages-forge-allowlist.test.anarbib.org TXT` ×2 : `https://codeberg.org/anarbib/anarbib.git` et `https://codeberg.org/AnarBib/anarbib.git`. Pas de A, AAAA ni TXT sur le nom lui-même. |
| Authentification Supabase | `site_url` = `https://app.anarbib.org` ; les *Redirect URLs* admises sont `app.anarbib.org` (×3), `app.anarbib.is`, `app.anarbib.org.br`, `localhost:5173` (×3). **`test.anarbib.org` n'y figure pas : rien à retirer.** |
| CORS des fonctions à liste fermée | `geocode`, `submit-cartography-entry`, `submit-gazette-contribution` répondent `access-control-allow-origin: https://app.anarbib.org` à une origine `test.anarbib.org` : **non admise.** |
| Dépôt | Deux mentions seulement, historiques : `ci.yml` (récit de la bascule du 20-21/08) et `docs/backlogs/ETAT-AVANCEMENT-multisessions.md` (« essai `test.anarbib.org` (19/08) »). Ni CSP, ni `public/`, ni `supabase/config.toml`, ni fonction, ni script ne le citent. Rien à modifier. |
| Autorisation du retrait | `git-pages-cli … --delete --dry-run` avec le jeton `~/anarbib-ops/git-pages.token` : **`dry-run ok`** (le serveur accepte, rien n'a été supprimé ; le site répondait toujours 200 après). |

## L'ordre compte : retirer le site AVANT le DNS

git-pages autorise un `DELETE` par la règle *forge DNS allowlist* : il lit le TXT
`_git-pages-forge-allowlist.test.anarbib.org` et vérifie que le jeton peut pousser sur le dépôt
qui y est nommé. **Si l'on retire le DNS d'abord, on ne peut plus retirer le site** : son
contenu resterait stocké chez Codeberg, inaccessible, mais hors de notre main. D'où l'ordre
ci-dessous. (README de git-pages : après un `DELETE`, les données restent stockées un temps
indéterminé mais deviennent totalement inaccessibles.)

## Les gestes

### 1. Retirer le site du serveur git-pages (Xavier)

Même image et même jeton que `scripts/ci/publier-front.sh`. Le jeton passe sur la ligne de
commande de la CLI (seule voie qu'elle offre) : visible dans `ps` le temps de l'appel.

**Dans WSL :**
```bash
cd ~
docker run --rm data.forgejo.org/git-pages/git-pages-cli:1.10.0 https://test.anarbib.org/ --server=codeberg.page "--token=$(cat ~/anarbib-ops/git-pages.token)" --delete
```

Attendu : un `result:` sans erreur et un code de sortie 0. Pour rejouer d'abord l'essai à
blanc, ajouter `--dry-run` en fin de ligne (attendu : `dry-run ok`).

### 2. Constater que le site ne sert plus rien

**Dans WSL :**
```bash
cd ~
curl -sS -o /dev/null -w '%{http_code}\n' https://test.anarbib.org/
curl -sS https://test.anarbib.org/ | grep -c 'index-DGmoP40U' || true
```

Attendu : un code autre que 200 (404 vraisemblablement) et `0`. Si l'on obtient encore 200
avec le vieux bundle, attendre une minute (`cache-control: max-age=60`) et recommencer avant
de toucher au DNS.

### 3. Retirer les trois enregistrements DNS chez OVH (Xavier)

Espace client OVH → *Noms de domaine* → `anarbib.org` → *Zone DNS*, filtrer sur `test`, et
supprimer **exactement** :

| Sous-domaine | Type | Cible |
|---|---|---|
| `test` | CNAME | `codeberg.page.` |
| `_git-pages-forge-allowlist.test` | TXT | `"https://codeberg.org/anarbib/anarbib.git"` |
| `_git-pages-forge-allowlist.test` | TXT | `"https://codeberg.org/AnarBib/anarbib.git"` |

⚠️ Ne pas confondre avec `_git-pages-forge-allowlist.app` (mêmes deux valeurs) : c'est celui
de la production. Le filtre « test » les sépare.

### 4. Vérifier à l'autorité

**Dans PowerShell :** (WSL n'a pas `dig`)
```powershell
Set-Location "C:\AnarBib"
foreach ($n in 'test.anarbib.org','_git-pages-forge-allowlist.test.anarbib.org','_git-pages-forge-allowlist.app.anarbib.org') { "$n :"; Resolve-DnsName $n -Type TXT -Server dns14.ovh.net -DnsOnly -ErrorAction SilentlyContinue | Where-Object Section -eq 'Answer' | ForEach-Object { "  $($_.Type) $($_.NameHost)$($_.Strings)" } }
```

Attendu : rien sous les deux noms `test`, et **toujours les deux TXT** sous
`_git-pages-forge-allowlist.app.anarbib.org` (contre-épreuve : la prod n'a pas été touchée).

### 5. Supabase et fonctions

Rien à faire : `test.anarbib.org` n'est ni dans les *Redirect URLs*, ni dans les origines des
fonctions à CORS fermé (relevé du 23/10 ci-dessus).

## Fait le 23/10/2026

- **Site** : `--delete` lancé par Xavier → `result: deleted`, code 0. Ensuite `/`, le bundle
  `index-DGmoP40U.js` et `sw.js` répondent **424** (« Failed Dependency », la page de Codeberg
  pour un nom sans site publié) : c'est l'effet attendu, pas une panne.
- **DNS** : les trois enregistrements supprimés chez OVH par Xavier. Vérifié aux **deux**
  serveurs d'autorité (`dns14.ovh.net`, `ns14.ovh.net`) : plus rien sous `test.anarbib.org` ni
  sous `_git-pages-forge-allowlist.test.anarbib.org` ; les deux TXT
  `_git-pages-forge-allowlist.app.anarbib.org` et le A de `app.anarbib.org` sont intacts.
- **Production** : `app.anarbib.org`, `app.anarbib.is`, `app.anarbib.org.br` en 200 après les
  deux gestes.

## Ce qui reste après le retrait

- **Service worker.** Le vieux front enregistrait `sw.js`. Un navigateur qui l'aurait ouvert
  garde une coquille en cache tant que le nom ne résout plus ; elle ne peut rien faire (clé
  désactivée, 401) et disparaît avec les données du site dans le navigateur.
- **Un futur site de test** ne doit jamais être un front de production téléversé sous un autre
  nom : soit une pile auto-hébergée avec sa propre base, soit rien. Et un essai sous un nom
  provisoire se retire le jour où il a servi — c'est l'oubli de ce geste qui a laissé ce front
  en ligne deux mois.
