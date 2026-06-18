# CHANTIER BASELINE — squash de l'historique de migrations (P1-3)

> Date : 2026-06-18. Réf : Audit 360° P1-3 / `AUDIT_derive_schema_2026-06-17.md`.
> But : rendre `supabase db reset` reconstructible (socle pré-2026-05-10 non
> capturé). **Étape ② (validation locale) FAITE et PROUVÉE.** Étape ③ (adoption
> sur `main`) **à exécuter en fenêtre coordonnée** (voir §4).

## 1. Diagnostic (rappel)

L'historique démarre le 2026-05-10 et **suppose une base préexistante** : aucune
migration ne crée les tables fondatrices (`book_holdings`, `books`, `profiles`,
`libraries`, `exemplares`…), ni les extensions, ni la MV catalogue
(`mv_books_catalog_list_v1`) / la vue `catalog_list_anon_v1`. Donc `db reset`
échoue dès la 1re migration. Le seul état fiable = la **live**.

## 2. Construire le baseline (depuis la live)

Le baseline = dump de schéma de la live + deux compléments hors-dump.

1. **Dump schéma** (lit la live, ignore les migrations) :
   ```bash
   supabase db dump --linked --schema public,api,ingest,private -f docs/db/schema_live_<date>.sql
   ```
2. **Préfixer les EXTENSIONS** (absentes du dump `--schema`) — idempotent, no-op
   en prod :
   ```sql
   CREATE SCHEMA IF NOT EXISTS "extensions";
   CREATE EXTENSION IF NOT EXISTS "pg_trgm"   WITH SCHEMA "extensions";
   CREATE EXTENSION IF NOT EXISTS "unaccent"  WITH SCHEMA "extensions";
   CREATE EXTENSION IF NOT EXISTS "pgcrypto"  WITH SCHEMA "extensions";
   CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";
   CREATE EXTENSION IF NOT EXISTS "pg_net"    WITH SCHEMA "extensions";
   ```
3. **Suffixer les JOBS pg_cron** (absents du dump `--schema` : ils vivent dans le
   schéma `cron`). Régénérer depuis la live AU MOMENT de l'exécution :
   ```sql
   select jobname, schedule, active, command from cron.job order by jobid;
   ```
   puis émettre un bloc `DO` gardé par `pg_cron`, qui pour chaque job fait
   `cron.unschedule(name)` (toléré) → `v := cron.schedule(name, sched, cmd)` →
   `cron.alter_job(v, active:=false)` si inactif (JAMAIS `UPDATE cron.job`).
   (Au 18/06 : 28 jobs, dont 3 inactifs — cross-library-digest,
   collective-removal-execute, cooptation-reminders.)

## 3. Validation locale — ✅ FAITE le 18/06 (zéro risque, reproductible)

```bash
git worktree add ../anarbib-baseline -b chantier-baseline <main>
# migrations/ réduit au seul baseline :
mv ../anarbib-baseline/supabase/migrations/2026*.sql /tmp/archive/
cp docs/db/schema_live_<date>.sql ../anarbib-baseline/supabase/migrations/20260510000000_baseline_live.sql
# + préfixe extensions + suffixe cron (cf. §2)
cd ../anarbib-baseline && supabase db reset      # LOCAL uniquement, jamais --linked
```
**Résultat 18/06** : `Finished supabase db reset` sans erreur ; base reconstruite
= **161 tables / 676 fonctions / 88 vues / 2 MV / 139 triggers / 226 policies**,
socle + orphelins + correctifs présents. `pg_trgm`/`unaccent` créées par le
baseline ; le reste no-op. Section cron skippée proprement (pg_cron absent du
stack local). **→ Le baseline reconstruit fidèlement la live.**

## 4. Adoption sur `main` — étape ③ (À FAIRE EN FENÊTRE COORDONNÉE)

⚠️ **NE PAS exécuter tant que des branches features sont en vol.** Au 18/06 :
`anarbib-p3`, `anarbib-tri-roles`, `anarbib-epub` actives → un squash de `main`
rendrait leurs fusions conflictuelles. Faire quand elles sont fusionnées + une
fenêtre calme.

**`repair` distant et squash repo sont en LOCKSTEP** (sinon le prochain
`db push` CI re-joue 439 migrations sur la prod) :

1. **Sauvegarde réversibilité** : dump `supabase_migrations.schema_migrations` +
   `cron.job` (le `repair` n'édite QUE l'historique, jamais le schéma — mais on
   garde un filet).
2. **Re-dump frais** de la live (cf. §2) → baseline à jour.
3. **Repo** : archiver les 439 fichiers (`git mv` vers `supabase/migrations_archive/`
   ou suppression — l'historique git les garde), ne laisser que le baseline.
4. **Reconcilier le distant** (le seul moment où l'on touche la live) :
   ```bash
   supabase migration repair --linked --status reverted <chaque version des 439>
   supabase migration repair --linked --status applied  20260510000000
   ```
5. **Vérifier** : `supabase migration list` → local = distant = `20260510000000` seul.
6. **Commit + push** (coordonné, pas de push concurrent), surveiller le pipeline.
7. Idéalement : **répéter d'abord 1→5 sur une branche Supabase de dev** pour
   répéter sans risque.

## 5. État au 18/06

- ② validé (ci-dessus). Worktree de validation : `~/anarbib-baseline` (scratch,
  supprimable). Baseline assemblé conservé : `docs/db/baseline_assembled_2026-06-18.sql`.
- ③ : non exécuté (attente fenêtre coordonnée). Procédure ci-dessus prête.
