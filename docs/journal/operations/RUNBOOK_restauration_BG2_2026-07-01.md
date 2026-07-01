---
Genre : référence opérationnelle
Statut : 🟢 référence
Décisions : applique REGISTRE §BG2 (BG2-1..BG2-14). Procédure éprouvée les 30/06 et 01/07/2026 (premiers dumps réels + tests de restauration).
Supersède : `RUNBOOK_sauvegardes_restauration_BG2_2026-06-17.md` (écrit au cadrage, avant implémentation — à archiver).
---

# RUNBOOK — Restauration des sauvegardes BG2

Procédure de restauration des sauvegardes chiffrées d'AnarBib. **Toutes les commandes ci-dessous ont été exécutées et validées** (30/06 : flux long ; 01/07 : flux court + storage + séquence complète).

> ⚠️ **Prérequis absolu, sans lequel RIEN n'est récupérable : la passphrase maître restic.**
> Elle est dans **Dashlane** (entrée « restic — dépôt sauvegarde AnarBib ») + copie hors-ligne, et en fichier local `~/.config/restic-anarbib.pass`. Sans elle, les trois dépôts ne sont qu'un bloc d'octets illisible. Aucune récupération n'est possible. **Vérifier qu'on y a accès AVANT de commencer.**

---

## 1. Architecture des sauvegardes

Trois dépôts restic distincts, chiffrés, chez **Herbes Folles** (CCL Lille, hors CLOUD Act), accès SFTP par clé SSH.

| Dépôt | Contenu | Rétention | Sélection |
|---|---|---|---|
| `…/anarbib-long`    | base durable : schéma `public` **moins** les PII (≈142 tables : catalogue, gouvernance, config) | 7/4/6 | denylist + filet |
| `…/anarbib-court`   | base sensible : 30 tables PII de `public` + `auth.users`/`identities`/`mfa_factors` | 7 jours | allowlist stricte |
| `…/anarbib-storage` | les 16 buckets Storage (≈430 Mo : numérisations, couvertures, portraits…) | 7/4/6 | miroir complet |

- **Hôte** : `bricolage.herbesfolles.org`, user `anarbib`, répertoire `/data/`.
- **Base restic** : `sftp:anarbib@bricolage.herbesfolles.org:/data/<depot>`.
- **Secrets** : passphrase restic → `~/.config/restic-anarbib.pass` (chmod 600) ; mot de passe DB → `~/.pgpass` (chmod 600) ; clé SSH → `~/.ssh/id_ed25519` (dans l'agent : `ssh-add`).

---

## 2. Préparer une session de restauration

À faire dans tous les cas avant de restaurer :

```bash
# 1. charger la clé SSH dans l'agent (passphrase de la clé demandée)
eval "$(ssh-agent -s)" ; ssh-add ~/.ssh/id_ed25519

# 2. pointer restic vers la passphrase maître
export RESTIC_PASSWORD_FILE=~/.config/restic-anarbib.pass

# 3. verifier l'acces a un depot (ex. long) + son integrite
export RESTIC_REPOSITORY=sftp:anarbib@bricolage.herbesfolles.org:/data/anarbib-long
restic snapshots        # liste les sauvegardes disponibles
restic check            # doit conclure : no errors were found
```

Outils requis : `restic` ≥ 0.16, `psql`/`pg_dump` ≥ 17, et `docker` (pour un test hors production).

---

## 3. Scénario A — Sinistre total (repartir de zéro)

Reconstruire toute la base sur une nouvelle instance. **L'ordre est impératif : `auth` → long → court → storage.** (Découvert à l'usage : le flux long dépend du schéma `auth` ; le flux court dépend de la structure posée par le long.)

### 3.0 — Choisir la cible et préparer `auth`

**Cas 1 — nouvelle instance Supabase (cas probable).** Le schéma `auth`, les rôles (`anon`, `authenticated`, `service_role`, `authenticator`) et les extensions **existent déjà**. Ne rien recréer. Les erreurs `already exists` sur `auth` pendant le rejeu sont **attendues et bénignes**.

**Cas 2 — Postgres nu (self-hosted, ou test Docker).** Il faut poser le squelette `auth` et les rôles **avant** de restaurer, sinon les `CREATE TABLE` du long échouent (colonnes `DEFAULT auth.uid()`) :

```sql
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $f$ SELECT NULL::uuid $f$;
DO $$ BEGIN CREATE TYPE auth.factor_type   AS ENUM ('totp','webauthn','phone'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE auth.factor_status AS ENUM ('unverified','verified');   EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE auth.aal_level     AS ENUM ('aal1','aal2','aal3');       EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE anon;          EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE authenticated; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE service_role;  EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE authenticator; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
```

### 3.1 — Récupérer les dumps depuis Herbes Folles

```bash
export RESTIC_PASSWORD_FILE=~/.config/restic-anarbib.pass
mkdir -p /tmp/restauration

RESTIC_REPOSITORY=sftp:anarbib@bricolage.herbesfolles.org:/data/anarbib-long \
  restic restore latest --tag flux-long  --target /tmp/restauration/long
RESTIC_REPOSITORY=sftp:anarbib@bricolage.herbesfolles.org:/data/anarbib-court \
  restic restore latest --tag flux-court --target /tmp/restauration/court

LONG=$(find /tmp/restauration/long  -name 'anarbib-long.sql'  | head -1)
COURT=$(find /tmp/restauration/court -name 'anarbib-court.sql' | head -1)
```

### 3.2 — Rejouer LONG puis COURT sur la cible

`CIBLE` = la chaîne de connexion de la **nouvelle** base (jamais la prod encore vivante).

```bash
psql "$CIBLE" -v ON_ERROR_STOP=0 < "$LONG"    # pose toute la structure de public + le catalogue
psql "$CIBLE" -v ON_ERROR_STOP=0 < "$COURT"   # ajoute les PII + les comptes par-dessus
```

`ON_ERROR_STOP=0` est **voulu** : des erreurs de contraintes croisées apparaissent (tables du court pointant entre elles, FK inter-flux). Elles sont **attendues** et n'empêchent pas le chargement des données — cf. §3.4 pour le contrôle.

### 3.3 — Restaurer le Storage

```bash
mkdir -p /tmp/restauration/storage
RESTIC_REPOSITORY=sftp:anarbib@bricolage.herbesfolles.org:/data/anarbib-storage \
  restic restore latest --tag flux-storage --target /tmp/restauration/storage
```

Puis **ré-uploader** vers la nouvelle instance. ⚠️ **Recréer d'abord les 16 buckets** avec leur visibilité d'origine (public/privé — voir la table du §1 du cadrage), *ensuite* pousser les fichiers, bucket par bucket :

```bash
# sens inverse du telechargement : local -> bucket
supabase storage cp --linked --experimental -r \
  /tmp/restauration/storage/.../<bucket> ss:///<bucket>
```

> Le ré-upload n'a **pas** encore été testé en conditions réelles (seul le download l'a été). À éprouver sur un bucket-témoin le jour d'un vrai sinistre, ou lors d'un exercice à froid.

### 3.4 — Vérifier

```bash
psql "$CIBLE" -c "select count(*) from pg_tables where schemaname='public';"   -- attendu ~172
psql "$CIBLE" -c "select count(*) from auth.users;"                            -- attendu = nb de comptes
psql "$CIBLE" -c "select count(*) from books;"                                 -- attendu ~2674
psql "$CIBLE" -c "select count(*) from emprestimos_v2;"                        -- non nul si emprunts existants
```

Repères éprouvés le 01/07 : **172** tables `public`, `auth.users` et `profiles` cohérents avec le nombre de comptes, `books` ≈ 2674.

---

## 4. Scénario B — Restauration partielle

Le cas courant : récupérer un élément précis sans tout reconstruire.

### 4.1 — Un fichier Storage effacé par erreur

```bash
export RESTIC_PASSWORD_FILE=~/.config/restic-anarbib.pass
export RESTIC_REPOSITORY=sftp:anarbib@bricolage.herbesfolles.org:/data/anarbib-storage
restic restore latest \
  --include /home/accattone/anarbib-ops/.storage-work/<bucket>/<chemin/du/fichier> \
  --target /tmp/recup
# puis re-uploader le fichier via : supabase storage cp --linked --experimental ...
```

### 4.2 — Une table (ou son contenu) à un instant donné

```bash
# recuperer le dump voulu (long ou court selon la table)
export RESTIC_REPOSITORY=sftp:anarbib@bricolage.herbesfolles.org:/data/anarbib-long
restic restore latest --tag flux-long --target /tmp/recup
SQL=$(find /tmp/recup -name 'anarbib-long.sql' | head -1)

# option A : extraire juste le bloc d'une table du fichier .sql (inspection/copie manuelle)
awk '/^COPY public\.<table> /{f=1} f{print} f&&/^\\\.$/{exit}' "$SQL"

# option B : rejouer tout le dump dans un Postgres jetable, puis exporter la table
docker run -d --name recup-tmp -e POSTGRES_PASSWORD=throwaway -p 55440:5432 postgres:17
# (poser le squelette auth du §3.0 cas 2 si le long ne se cree pas)
docker exec -i recup-tmp psql -U postgres -d postgres -v ON_ERROR_STOP=0 < "$SQL"
docker exec recup-tmp pg_dump -U postgres -d postgres --data-only --table=public.<table> > /tmp/<table>.sql
docker rm -f recup-tmp
```

### 4.3 — Revenir à une version antérieure (pas la dernière)

```bash
restic snapshots --tag flux-long           # lister toutes les sauvegardes datees
restic restore <ID_du_snapshot> --target /tmp/recup   # au lieu de "latest"
```

La profondeur disponible dépend de la rétention : **long/storage** remontent jusqu'à ~6 mois (7/4/6) ; **court** ne remonte qu'à **7 jours** (par conception RGPD — les PII ne sont pas conservées au-delà).

---

## 5. Pièges connus (leçons de terrain)

- **Ordre impératif** : `auth` → long → court. Le long pose la structure `public` dont dépendent les tables PII du court.
- **Postgres nu** : sans le squelette `auth` (types ENUM) + les 4 rôles, les `CREATE TABLE` échouent. Sur une instance Supabase, ils existent déjà.
- **Erreurs à la restauration** : les `relation/type does not exist` (dépendances inter-flux) et `role does not exist` (rôles Supabase sur Postgres nu) sont **normales**. Le juge de vérité, ce sont les **comptages** (§3.4), pas le compte d'erreurs.
- **`ON_ERROR_STOP=0`** obligatoire au rejeu, sinon la première erreur bénigne arrête tout.
- **Court = 7 jours** : ne pas s'attendre à retrouver une PII effacée il y a deux semaines. C'est voulu.
- **Passphrase perdue = tout perdu.** Il n'y a pas de mécanisme de récupération. Vérifier régulièrement qu'elle est bien dans Dashlane ET hors-ligne.
- **Ré-upload Storage** : non encore éprouvé. À tester lors d'un exercice à froid.

---

## 6. Aide-mémoire — commandes clés

```bash
# session
eval "$(ssh-agent -s)" ; ssh-add ~/.ssh/id_ed25519
export RESTIC_PASSWORD_FILE=~/.config/restic-anarbib.pass

# inspecter un depot
export RESTIC_REPOSITORY=sftp:anarbib@bricolage.herbesfolles.org:/data/anarbib-long
restic snapshots ; restic check

# outil quotidien (hors repo)
~/anarbib-ops/anarbib-bg2.sh check
~/anarbib-ops/anarbib-bg2.sh backup long|court|storage|all
~/anarbib-ops/anarbib-bg2.sh restore-test      # test complet sur conteneur jetable
```

*Fin du runbook. Pour la doctrine de partition : REGISTRE §BG2. Pour l'outil : `~/anarbib-ops/anarbib-bg2.sh`.*
