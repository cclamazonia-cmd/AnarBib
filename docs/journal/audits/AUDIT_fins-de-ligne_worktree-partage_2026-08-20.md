# AUDIT — Fins de ligne et worktree partagé Windows / WSL

**Date** : 20 août 2026
**Statut** : ✅ **CLÔTURÉ** — diagnostic puis correction appliquée le jour même (§10)
**Périmètre** : le worktree unique `C:\AnarBib` ↔ `/home/accattone/anarbib`, attaqué par deux Git différents
**Déclencheur** : deux Git donnaient deux `git status` disjoints sur le même dossier, le même jour

---

## 1. Résumé exécutif

Un seul worktree, deux Git aux politiques de conversion **contradictoires**, qui écrivent dans le même index et le même répertoire de travail :

| | Git Windows | Git WSL |
|---|---|---|
| Version | 2.55.0.windows.4 | 2.53.0 |
| `core.autocrlf` | **`true`** (config *system*) | non défini → `false` |
| Fichiers vus modifiés | 14 | 52 |
| Nature de ces diffs | **100 % changements de mode** | **100 % fins de ligne** |
| Recouvrement des deux listes | *aucun* | *aucun* |

Chacun des deux ne voit que le bruit produit par l'autre, et croit son propre bruit invisible. C'est ce qui rend la panne coûteuse : **aucun des deux points de vue ne suffit à voir le problème**.

Ce n'est pas théorique. La divergence a **déjà produit un bug ce matin** (§5).

---

## 2. Mécanisme

`core.autocrlf=true` vient de la config *system* de Git for Windows :

```
file:C:/Program Files/Git/etc/gitconfig    core.autocrlf=true
```

C'est le défaut de l'installeur Git for Windows, pas un choix fait sur ce projet. Il signifie : *convertir LF → CRLF au checkout, CRLF → LF au commit.* Parfaitement cohérent — tant qu'un seul Git touche le worktree.

Ici, un checkout côté Windows a réécrit 52 fichiers en CRLF **sur le disque**. Le dépôt, lui, contient toujours du LF. Résultat :

- **Git Windows** reconvertit à la volée quand il compare → il les voit **propres** ;
- **Git WSL** (`autocrlf=false`) compare les octets bruts → il les voit **tous modifiés**.

### Preuve

Quel blob chaque Git écrirait-il pour le même `README.md` sur disque ?

```
blob dans HEAD           : 2a52671cfd1a0fbf385f0410ca2bc3fd130bb8a8
blob que Windows écrirait: 2a52671cfd1a0fbf385f0410ca2bc3fd130bb8a8   → identique, donc « propre »
blob que WSL écrirait    : d22339936ed2931f62243c61cc04a72f5a5f79e6   → différent, donc « modifié »
```

**Le danger est unidirectionnel** : committer un de ces 52 fichiers **depuis WSL** écrit du CRLF dans le dépôt. Depuis Windows, c'est sans risque. Un `git add -A` côté WSL produirait un commit de ~79 750 lignes ajoutées et autant de supprimées, sans un seul changement réel.

### Le contenu n'est pas en cause

```
git diff --ignore-cr-at-eol --stat   →   (vide)
```

Les 52 fichiers ne diffèrent **que** par les fins de ligne. Aucun travail en cours d'une autre session n'est en jeu — ce qui rend la normalisation sûre (§7).

---

## 3. Pourquoi maintenant

Le `.gitattributes` a été créé **le 19 août 2026**, précisément pour empêcher les scripts shell de partir en CRLF (`/usr/bin/env: 'bash\r': No such file or directory`). Il fait son travail : aucun des fichiers qu'il protège n'est dans la liste des 52.

Mais sa couverture est **une liste blanche**, pas une règle générale :

```
*.sh                    text eol=lf
.githooks/pre-commit    text eol=lf
deploy/Caddyfile        text eol=lf
deploy/compose.yml      text eol=lf
deploy/genkeys.mjs      text eol=lf
deploy/*.example        text eol=lf
*.docx *.pdf *.woff2 *.wasm *.png *.jpg   binary
```

Tout le reste du dépôt reste livré à `core.autocrlf`. Le `.gitattributes` a donc **sanctuarisé la pile de déploiement et révélé le problème partout ailleurs**, sans le résoudre.

Lacune annexe : `*.svg`, `*.webp`, `*.ico`, `*.woff` ne sont pas déclarés binaires. C'est pour ça que `public/img/anarbib-logo.svg` figure dans les 52.

---

## 4. Les 52 fichiers, par risque réel

| Catégorie | Nombre | Effet du CRLF |
|---|---|---|
| Locales i18n + `package.json` / `package-lock.json` | 12 | inerte — les parseurs JSON ignorent `\r` |
| Fonctions Deno (`supabase/functions/**`) | 8 | inerte |
| Migrations et tests SQL | 10 | inerte — psql tolère |
| Sources `.jsx` / `.js` (dont `eslint.config.js`) | 10 | inerte — le bundler tolère |
| Docs `.md` / `.txt`, `supabase/config.toml`, `.gitignore`, `.gitattributes` | 8 | inerte |
| SVG du logo | 1 | inerte au rendu ; symptôme de la lacune §3 |
| `.forgejo/workflows/ci.yml` | 1 | inerte — YAML normalise les sauts de ligne |
| **`.env.example`** | 1 | **nuisible — voir §5** |
| **`public/_redirects`** | 1 | **nuisible si build local — voir §6** |

L'écrasante majorité est du bruit. Deux fichiers ne le sont pas.

---

## 5. Dommage déjà causé — `.env.example` → `.env.local`

```
.env.example  dans HEAD  : LF
.env.example  sur disque : CRLF      ← réécrit par le checkout Windows
.env.local    (non versionné) : CRLF ← copié depuis l'exemple
```

Ce `.env.local` en CRLF est **exactement** ce qui a cassé `scripts/upload-ocr-assets.mjs` ce matin : sa fonction `readEnvLocal()` splittait sur `'\n'`, le `\r` restait collé en fin de ligne, et comme `.` ne matche pas `\r` en JavaScript, la regex `/^([A-Z_]+)=(.*)$/` échouait sur **toutes** les lignes. Aucune clé extraite, et le message d'erreur accusait une variable pourtant présente.

Corrigé en `9a4d372b5`, puis factorisé en `bcff4f10c`. Mais la correction traite le symptôme côté lecteur : **la source du CRLF, elle, est toujours là**, et alimentera le prochain `.env.local` copié.

C'est le seul dommage avéré à ce jour.

---

## 6. Risque latent — `public/_redirects`

La règle de repli SPA vaut aujourd'hui, sur disque :

```
/*  /index.html  200^M
```

Et ce `\r` **survit au build** : `dist/_redirects` le contient aussi. Si l'analyseur de Codeberg Pages découpe sur `\n` sans retirer le `\r`, le code de statut devient `200\r`, la règle est rejetée, et **toute route profonde retombe en 404**.

**La production n'est pas affectée.** Le déploiement passe par la CI Forgejo (`.forgejo/workflows/ci.yml`), qui construit depuis un clone frais sous Linux : le fichier y est en LF. Le risque ne se matérialise que si quelqu'un déploie depuis ce worktree Windows pollué.

Sévérité : basse aujourd'hui, élevée le jour d'un déploiement manuel de secours — c'est-à-dire précisément le jour où l'on ne veut pas d'une panne supplémentaire.

---

## 7. Constats annexes

### 7.1 Le mode fantôme (14 fichiers)

Git Windows signale 14 changements de mode `100755 → 100644` que Git WSL ne voit pas. Ce ne sont **pas** de vrais changements : Git for Windows ne sait pas lire le bit exécutable à travers `\\wsl.localhost` (9p) et conclut à son absence. `ls -l` depuis Git Bash affiche pourtant `-rwxr-xr-x` sur les mêmes fichiers — les deux outils ne lisent pas la même source.

Conséquence concrète : committer ces changements **retirerait pour de bon** le bit exécutable de `deploy/bootstrap.sh`, `scripts/backup/anarbib-backup.sh`, `scripts/ci/run-sql-suites.sh` et consorts.

Ne pas « corriger » par `core.fileMode=false` : ça aveuglerait aussi le côté WSL, qui lui lit les modes correctement, et empêcherait d'enregistrer un `chmod +x` légitime.

### 7.2 Le garde-fou SQL n'a jamais tourné

`core.hooksPath` n'est pas défini dans ce worktree et `.git/hooks/pre-commit` n'existe pas. Le hook `.githooks/pre-commit.ps1` — garde-fou de la doctrine de création d'objets sécurisés — **ne s'exécute donc jamais**.

Le README l'annonce pourtant comme actif (« Le hook `.githooks/pre-commit.ps1` enforce la doctrine »), avec l'activation mentionnée entre parenthèses. Un backlog archivé va plus loin : « Le pre-commit hook `.githooks/pre-commit` enforce automatiquement. » Hors périmètre de cet audit, mais à savoir : ce filet est décrit comme tendu et ne l'est pas.

---

## 8. Recommandations

**R1 — Régler le fond, dans le dépôt.** Ajouter en tête du `.gitattributes` :

```
* text=auto eol=lf
```

Les attributs **priment sur `core.autocrlf`**. Les deux Git s'alignent alors quelle que soit leur configuration locale, y compris sur un clone frais chez quelqu'un d'autre. C'est la seule mesure qui survive à une réinstallation de Git ou à l'arrivée d'un nouveau poste.

> **Correction (§10)** — « coût nul, les blobs sont déjà en LF » était inexact. Deux fichiers du dépôt portent bien du CRLF dans leur blob et auraient été réécrits. Voir §10.2.

**R2 — Normaliser le worktree, une fois.** Depuis WSL, après avoir revérifié que `git diff --ignore-cr-at-eol --stat` est bien vide :

```
git diff --name-only | xargs -r git checkout --
```

Restaure les 52 fichiers en LF. Aucun contenu réel n'est perdu — c'est prouvé par la vérification qui précède, à refaire au moment de l'exécution puisqu'une autre session peut avoir commencé un vrai travail entre-temps.

**R3 — Compléter les règles binaires** : `*.svg`, `*.webp`, `*.ico`, `*.woff` (lacune §3).

**R4 — Un seul Git sur ce worktree.** Tant que R1 n'est pas en place, privilégier le Git de WSL pour tout commit : c'est celui dont la vue correspond à ce que voient la CI et les conteneurs. Et ne jamais stager un changement de mode vu depuis Windows (§7.1).

**R5 — Hors périmètre** : décider si le hook de §7.2 doit être câblé (`git config core.hooksPath .githooks`) ou si le README doit cesser de le présenter comme actif.

---

## 9. Ce qui n'a pas été fait

**Rien n'a été modifié.** Aucun fichier normalisé, aucune configuration touchée, aucune règle ajoutée. Le `.gitattributes` était en cours d'édition par une autre session au moment de l'audit, et arbitrer la politique de fins de ligne d'un dépôt partagé n'est pas une décision à prendre sous les pieds de quelqu'un.

Les commits de la session du 20 août (`9a4d372b5`, `bcff4f10c`, `53abc5e7d`, `6f95dd8ef`, `95ca2aaeb`) ont été vérifiés : **zéro ligne CRLF** dans les six fichiers concernés sur `origin/main`.

*Cette section décrit l'état au moment du diagnostic. La correction a été appliquée ensuite, sur décision explicite — voir §10.*

---

## 10. Suite donnée — correction appliquée le 20 août 2026

### 10.1 Ce qui a été fait

1. **Worktree normalisé.** Les 52 fichiers restaurés en LF, après revérification que `git diff --ignore-cr-at-eol --stat` était bien vide et que l'index était vide. `.env.example` et `public/_redirects` sont repassés en LF — les deux seuls nuisibles de la liste.
2. **Règle de base ajoutée** au `.gitattributes` : `* text=auto eol=lf`, en tête, les règles spécifiques la surchargeant ensuite.
3. **Règles binaires complétées** : `*.svg`, `*.webp`, `*.ico`, `*.woff`, `*.gz`, `*.traineddata`.

### 10.2 Ce que la mesure a démenti

R1 annonçait un coût nul au motif que tous les blobs étaient déjà en LF. **C'était faux.** Un `git add --renormalize .` a révélé deux fichiers dont le blob contient réellement du CRLF :

| Fichier | Diff qu'aurait produit la renormalisation |
|---|---|
| `public/vendor/leaflet/leaflet.css` | 1 322 lignes |
| `supabase/migrations/20260510000000_baseline_live.sql` | 21 236 lignes |

Les deux sont exemptés par `-text` (aucune conversion, dans aucun sens — les deux Git s'accordent donc quand même, ce qui est l'objectif) :

- **leaflet.css** est du tiers vendorisé : on garde les octets amont ;
- **la baseline** est un dump historique déjà appliqué en production. Réécrire 21 000 lignes d'un fichier de migration pour une règle cosmétique n'est pas un risque à prendre en passant. À trancher à froid si le sujet revient.

Au passage, cela corrige la note de l'ancien `.gitattributes`, qui écartait `*.sql` par crainte de renormaliser « les 124 migrations » : la crainte portait en réalité sur **un seul** fichier. Toutes les autres migrations étaient déjà en LF dans le dépôt.

### 10.3 Vérification

Les deux Git résolvent désormais les mêmes attributs et écriraient le **même blob** pour le même fichier sur disque :

```
blob dans HEAD (README.md) : 2a52671cfd1a0fbf385f0410ca2bc3fd130bb8a8
blob que Windows écrirait  : 2a52671cfd1a0fbf385f0410ca2bc3fd130bb8a8
blob que WSL écrirait      : 2a52671cfd1a0fbf385f0410ca2bc3fd130bb8a8
```

Et les deux exemptions tiennent des deux côtés : `leaflet.css` et la baseline sont inchangés par un passage à l'index, depuis Windows comme depuis WSL. Après correction, `git add --renormalize .` ne stage plus que le `.gitattributes` lui-même.

### 10.4 Ce qui reste ouvert

- **§7.1, le mode fantôme** — non traité. Il ne vient pas des fins de ligne mais de l'incapacité de Git for Windows à lire le bit exécutable à travers `\\wsl.localhost`. Pas de correctif propre : `core.fileMode=false` aveuglerait aussi le côté WSL. La parade reste de committer depuis WSL et de ne jamais stager un changement de mode vu depuis Windows.
- **§7.2, le hook jamais câblé** — non traité, hors périmètre. Décision à prendre : le câbler, ou cesser de le présenter comme actif dans le README.
