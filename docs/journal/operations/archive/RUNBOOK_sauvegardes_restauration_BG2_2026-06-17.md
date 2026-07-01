# RUNBOOK — Sauvegardes & restauration AnarBib (#BG2)

> Chaîne de sauvegarde/restauration **hors fournisseur**. Réf : Audit 360° du
> 17/06/2026, P0 #BG2. Scripts associés : `scripts/backup/anarbib-backup.sh`
> + `scripts/backup/anarbib-backup.env.example`.
>
> **Périmètre des données** (au 17/06/2026) : base Postgres ≈ 80 Mo (149 tables)
> + Storage ≈ 430 Mo (16 buckets) → **≈ 500 Mo au total**. Tient partout.

## 0. Outils

- **restic** (chiffrement + déduplication + snapshots + rétention) — `apt install restic`
- **rclone** (téléchargement du Storage via l'endpoint S3 de Supabase) — `apt install rclone`
- **pg_dump / pg_restore / psql** (client PostgreSQL ≥ 15) — `apt install postgresql-client`

## 1. Mise en place (une fois, par cible)

1. **Mot de passe restic** : générer (`openssl rand -base64 32`), le stocker dans
   `RESTIC_PASSWORD_FILE` (chmod 600) **ET** le sauvegarder à part (gestionnaire de
   mots de passe + copie hors-ligne). ⚠️ perte du mot de passe = sauvegardes
   illisibles à jamais.
2. **Initialiser le dépôt** : `RESTIC_REPOSITORY=... RESTIC_PASSWORD_FILE=... restic init`
3. **rclone** : `rclone config` → remote `supabase-s3` de type s3 (endpoint S3 de
   Supabase, clés S3 du dashboard Storage). Vérifier : `rclone lsd supabase-s3:`
   (doit lister les buckets).
4. **Config** : copier `anarbib-backup.env.example` → `anarbib-backup.env`, remplir,
   `chmod 600`. La stocker **hors dépôt** sur le VPS (ex. `/etc/anarbib/`).
5. **Test à blanc** : `./anarbib-backup.sh /etc/anarbib/anarbib-backup.env` puis
   `restic snapshots` (un snapshot doit apparaître).
6. **Cron** (sur le VPS, modèle pull, ~03h00 UTC) :
   ```
   0 3 * * *  /srv/anarbib/scripts/backup/anarbib-backup.sh /etc/anarbib/anarbib-backup.env >> /var/log/anarbib-backup.log 2>&1
   ```
   Disque externe (copie froide mensuelle) : lancer manuellement à chaque
   branchement, avec un `.env` pointant `RESTIC_REPOSITORY=/mnt/hdd/restic-anarbib`,
   puis `restic check` avant de débrancher.

## 2. Cibles recommandées (règle 3-2-1)

| Copie | Emplacement | Cadence | Rôle |
|---|---|---|---|
| 1 | Supabase (live) | continu | production |
| 2 | VPS Lille (Herbes Folles) | nocturne (cron) | chaude, off-fournisseur |
| 3 | VPS Lyon (UCL / Sud-info) | nocturne (cron) | chaude, org. indépendante |
| 4 | HDD externe (1 To / 2 To) | mensuelle | **froide / hors-ligne** (bus-factor) |

≥ 2 emplacements **organisationnellement distincts** + ≥ 1 hors-ligne.

## 3. Vérifier l'état des sauvegardes

```bash
export RESTIC_REPOSITORY=... RESTIC_PASSWORD_FILE=...
restic snapshots                 # historique
restic stats latest              # taille
restic check                     # intégrité (ajouter --read-data pour tout relire)
```

## 4. RESTAURATION (le vrai objectif de #BG2)

> Toujours restaurer dans une cible **neuve/jetable** d'abord, jamais par-dessus
> la prod sans certitude.

### 4.1 Extraire un snapshot
```bash
restic snapshots                                   # repérer l'ID voulu
restic restore latest --target /tmp/anarbib_restore
# -> /tmp/anarbib_restore/<staging>/db, /storage, /secrets
```

### 4.2 Restaurer la base
Vers un Postgres cible (nouveau projet Supabase, ou instance self-hosted) :
```bash
# format custom (recommandé) :
pg_restore --no-owner --no-privileges --clean --if-exists \
  -d "$TARGET_DB_URL" /tmp/anarbib_restore/**/db/anarbib_*.dump
# ou, à partir du SQL texte :
gunzip -c /tmp/anarbib_restore/**/db/anarbib_*.sql.gz | psql "$TARGET_DB_URL"
```

### 4.3 Restaurer le Storage
```bash
# remonter chaque bucket vers la cible (remote rclone de la cible) :
rclone copy /tmp/anarbib_restore/**/storage  cible-s3: --fast-list --transfers 8
```
⚠️ recréer d'abord les buckets côté cible (mêmes noms + visibilité public/privé —
cf. la liste des 16 buckets ci-dessous) avant le `rclone copy`.

### 4.4 Restaurer les secrets / config
Replacer `.env.local` et les secrets des Edge Functions depuis
`/tmp/anarbib_restore/**/secrets/`, puis redéployer (functions + `db push`).

### 4.5 Vérifier l'intégrité
```bash
psql "$TARGET_DB_URL" -c "select count(*) from public.books;"
psql "$TARGET_DB_URL" -c "select count(*) from public.user_library_memberships;"
psql "$TARGET_DB_URL" -c "select count(*) from public.emprestimos_v2;"
```
Comparer aux ordres de grandeur connus. Tester un login + une recherche OPAC.

## 5. Exercice de restauration (drill) — OBLIGATOIRE

Une sauvegarde jamais restaurée n'existe pas. **Au premier setup, puis chaque
trimestre** : dérouler §4 dans un Postgres jetable (`docker run postgres`),
restaurer DB + un bucket, vérifier les comptages, **noter la date du dernier
drill réussi ici** :

| Date drill | Par | Résultat | Notes |
|---|---|---|---|
| (à remplir) | | | |

## 6. RGPD & sécurité

- **Chiffrement au repos par restic** → les hébergeurs des VPS ne stockent que du
  **chiffré opaque** (aucune donnée personnelle lisible ; clé tenue par AnarBib).
- **Rétention bornée** (GFS ci-dessus) — ne pas conserver de PII indéfiniment ;
  aligner sur la politique de rétention (phase RGPD).
- **Buckets sensibles** présents dans la sauvegarde : `anarbib-carte-rede`
  (adresses/contacts de collectifs), `pdf-restrito`, `catalogos_parceiros_raw`,
  `*-regimentos-private` → le chiffrement est **non négociable**.
- **Accès** : un compte SFTP dédié par VPS, clé SSH, pas de mot de passe.

## 7. Annexe — buckets Storage (au 17/06/2026)

Publics : `anarbib-pdf-public` (294 Mo), `covers` (37 Mo), `library-ui-assets`
(36 Mo), `anarbib-media-public` (13 Mo), `authors` (10 Mo),
`library-regimentos-public`, `library-privacy-public`, `anarbib-epub-public`.
Privés : `pdf-restrito`, `anarbib-carte-rede`, `catalogos_parceiros_raw`,
`library-regimentos-private`, `network-map`, `anarbib-media-restricted`,
`partner-catalog-deposits`, `anarbib-epub-restricted`.
