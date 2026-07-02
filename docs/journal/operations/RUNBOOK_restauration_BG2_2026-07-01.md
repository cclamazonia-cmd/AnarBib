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

### 3.2-bis — Rejouer les effacements (pseudonymisation BG2-14)

**Pourquoi.** Un dump long *antérieur* à un effacement contient encore le vrai
`user_id` des personnes qui ont depuis exercé leur droit à l'effacement. Le
rejouer tel quel (§3.2) **ressuscite** ces identités dans les tables de
gouvernance `network_*`. Il faut les re-pseudonymiser d'après `erasure_log`
(restauré avec le dump long) — sinon violation RGPD.

**Prérequis — réinjecter le sel Vault.** Le rejeu recalcule les jetons ; il lui
faut le **même sel** que celui ayant servi à `erasure_log`. Réinjecter
`pseudonym_salt` sur la CIBLE depuis la gestion de secrets hors-ligne
(Dashlane + clé USB) :
```bash
# Le sel s'affiche une fois pour etre injecte ; ne PAS le laisser dans l'historique.
export HISTIGNORE='*SALT*:*create_secret*'
read -rs -p "Sel pseudonym_salt (colle depuis Dashlane) : " SALT; echo
psql "$CIBLE" -v salt="$SALT" <<'SQL'
SELECT vault.create_secret(:'salt', 'pseudonym_salt', 'Sel HMAC BG2-14 (reinjecte restauration)');
SQL
unset SALT
```
⚠️ Si le sel réinjecté **diffère** de l'original, les jetons recalculés ne
correspondront pas à `erasure_log` : le rejeu ne purgera rien (silencieusement).
D'où l'importance vitale de la conservation exacte du sel. Vérifier après coup
(§ vérification) que le rejeu a bien touché des lignes si `erasure_log` est non vide.

**Le rejeu.** Pour chaque colonne d'acteur des `network_*`, remplacer par le
jeton tout `user_id` dont le jeton recalculé figure dans `erasure_log`. Le jeton
étant déterministe, une passe par colonne suffit (pas de boucle par personne) :
```bash
psql "$CIBLE" <<'SQL'
DO $rejeu$
DECLARE
  v_total int := 0; v_n int;
  -- (table, colonne) des 19 colonnes d'acteur BG2-14
  c record;
BEGIN
  -- CORRECTIF FK/PK (20260702) : materialiser d'abord les comptes pseudonymes.
  -- Sans cela, remplacer user_id par un jeton non materialise viole les FK des
  -- network_* (17 -> auth.users, 2 -> profiles) et les 6 PK. Meme correctif que
  -- fn_delete_my_account (migration 20260702081711). Autonome (auth.users +
  -- profiles explicites), idempotent (ON CONFLICT DO NOTHING), aucune PII.
  INSERT INTO auth.users (id, email, role, aud, raw_app_meta_data, raw_user_meta_data)
  SELECT e.pseudonym_token,
         e.pseudonym_token::text || '@pseudonimizado.anarbib.local',
         'authenticated', 'authenticated',
         '{"provider":"pseudonymized","providers":["pseudonymized"]}'::jsonb,
         '{"first_name":"Membro","last_name":"pseudonimizado"}'::jsonb
    FROM public.erasure_log e
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO profiles (id)
  SELECT e.pseudonym_token FROM public.erasure_log e
  ON CONFLICT (id) DO NOTHING;

  FOR c IN
    SELECT * FROM (VALUES
      ('network_admin_collective_removal_proposals','proposed_user_id'),
      ('network_admin_collective_removal_proposals','proposed_by'),
      ('network_admin_collective_removal_proposals','cancelled_by'),
      ('network_admin_collective_removal_votes','voter_user_id'),
      ('network_admin_cross_library_actions_log','actor_user_id'),
      ('network_administrator_audit','user_id'),
      ('network_administrator_audit','actor_user_id'),
      ('network_administrator_audit','target_user_id'),
      ('network_administrator_cooptation_proposals','proposed_user_id'),
      ('network_administrator_cooptation_proposals','proposed_by'),
      ('network_administrator_cooptation_votes','voter_user_id'),
      ('network_administrators','user_id'),
      ('network_contributors','user_id'),
      ('network_contributors','sponsored_by'),
      ('network_reviewers','user_id'),
      ('network_reviewers','added_by_user_id'),
      ('network_staff','user_id'),
      ('network_staff','added_by_user_id'),
      ('network_staff','updated_by_user_id')
    ) AS t(tbl, col)
  LOOP
    EXECUTE format(
      'UPDATE public.%I SET %I = public.fn_pseudonymize_token(%I) '
      'WHERE %I IS NOT NULL '
      'AND public.fn_pseudonymize_token(%I) IN (SELECT pseudonym_token FROM public.erasure_log)',
      c.tbl, c.col, c.col, c.col, c.col);
    GET DIAGNOSTICS v_n = ROW_COUNT; v_total := v_total + v_n;
  END LOOP;
  -- display_name : re-pseudonymiser les contributeurs deja pseudonymises
  UPDATE public.network_contributors
     SET display_name = user_id::text
   WHERE user_id IN (SELECT pseudonym_token FROM public.erasure_log);
  RAISE NOTICE 'Rejeu BG2-14 : % ligne(s) re-pseudonymisee(s).', v_total;
END $rejeu$;
SQL
```

**Vérification.** Aucun `user_id` effacé ne doit subsister en clair. Contrôle :
si `erasure_log` est non vide mais le rejeu a touché 0 ligne, suspecter un sel
incorrect. Sinon, le long restauré est conforme et on peut poursuivre (§3.3).

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

- **`trap RETURN` ≠ `trap EXIT` sous `set -e`.** Un `trap … RETURN` local **ne se déclenche pas** quand `set -e` fait sortir le script sur l'échec d'une commande (ex. `restic` qui n'atteint pas le serveur). Conséquence corrigée le 01/07 : un dump PII en clair pouvait survivre dans `$WORK`. Le nettoyage critique passe désormais par un `trap cleanup_work EXIT` **global** sur `$WORK/*.sql` (cf. REGISTRE BG2-AUTO-5). Ne jamais confier l'effacement d'un dump PII à un `trap RETURN` local.

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

## 7. Exploitation courante (sauvegardes automatiques)

*Les trois flux sont planifiés par **timers systemd user** sous WSL2 (cf. REGISTRE §BG2 suite, BG2-AUTO-1..5). Cette section décrit l'exploitation courante, pas la restauration.*

**Rappel de couverture.** Les timers ne tirent que **PC allumé et instance WSL up**. Une tâche planifiée Windows (`AnarBib-WSL-Boot`, déclencheur *à l'ouverture de session*) démarre l'instance au login ; le `linger` la maintient. PC éteint plusieurs jours = pas de tir sur l'intervalle ; `Persistent=true` rattrape **un** tir par timer au réveil.

### 7.1 — Vérifier l'état des sauvegardes automatiques

```bash
# Prochaines echeances + derniers tirs des trois timers
systemctl --user list-timers 'anarbib-*' --all

# Un backup a-t-il echoue ? (le drapeau n'existe que si oui)
cat ~/anarbib-ops/.last-failure 2>/dev/null || echo 'aucun echec signale'

# Journal detaille d'un flux (court / long / storage)
journalctl --user -u anarbib-backup-court.service -n 40 --no-pager
```

L'alerte jaune `[AnarBib] Un backup a ECHOUE` à l'ouverture du terminal (via `.bashrc`) signale un drapeau présent. Le drapeau **s'efface tout seul** au prochain tir réussi.

### 7.2 — Déclencher un tir manuel (hors planning)

```bash
# Lancer immediatement un flux (le timer reste inchange)
systemctl --user start anarbib-backup-court.service

# Suivre en direct
journalctl --user -u anarbib-backup-court.service -f
```

Équivaut à `~/anarbib-ops/anarbib-bg2.sh backup court`, mais passe par systemd (donc `OnFailure` + drapeau actifs).

### 7.3 — Où sont les pièces

- **Units** : `~/.config/systemd/user/anarbib-backup-{court,long,storage}.{service,timer}` + `anarbib-backup-failure@.service`.
- **Script de notif** : `~/anarbib-ops/anarbib-notify-failure.sh`.
- **Clé automate** : `~/.ssh/id_ed25519_bg2` (sans passphrase), routée par `~/.ssh/config` vers Herbes Folles.
- **Tâche Windows d'amorçage** : `schtasks /Query /TN AnarBib-WSL-Boot` (côté PowerShell).

### 7.4 — Après modification d'une unit

```bash
systemctl --user daemon-reload
systemctl --user list-timers 'anarbib-*' --all   # verifier les echeances
```

### 7.5 — Limite connue de la détection (angle mort « jamais démarré »)

La détection d'échec (drapeaux `.last-failure` pour les backups, `.last-failure-runner`
pour la CI, cf. §7.1) repose sur `OnFailure=` systemd : un drapeau se pose quand un
service **démarre puis échoue**. Elle a un **angle mort assumé** : le cas où le service
**ne démarre jamais** — PC éteint toute la période, WSL non amorcé au login, Docker
Desktop absent au boot, timer jamais déclenché. Dans ce cas **aucun drapeau ne se pose** :
il n'y a pas d'erreur à signaler, seulement un *silence*. Le dispositif détecte les
**erreurs**, pas les **silences**.

**Pourquoi c'est structurel.** Détecter « ça n'a jamais tourné » exige un observateur
**externe** au système observé : quand le PC est éteint, tout observateur *interne* l'est
aussi et ne peut pas alerter. C'est le même angle mort pour les backups (noté BG2-AUTO-4,
« dead man's switch niveau 3 reporté ») et pour le runner CI (même nature).

**Parade actuelle (manuelle).** En attendant un mécanisme externe, vérifier
**périodiquement à la main** que les sauvegardes tournent, via §7.1 (`list-timers` +
derniers snapshots restic). Un `restic snapshots` dont le dernier tir remonte à plus
d'une période = alerte, même sans drapeau.

**Piste (quand pertinent).** Un *dead man's switch* externe — service tiers type
healthchecks.io, ou un cron sur le futur **VPS EU** — qui reçoit un ping à chaque tir
réussi et alerte par mail si le ping manque. Converge naturellement avec la migration
VPS (où le VPS-pull remplacera les timers WSL, cf. BG2-AUTO-1) : l'observateur externe
naîtra avec l'hébergement distant. Non prioritaire tant que le PC sert de poste de
travail quotidien (donc allumé souvent).
