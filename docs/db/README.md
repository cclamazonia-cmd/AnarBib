# docs/db/ — Dumps Supabase

Ce dossier archive les dumps SQL du schéma Supabase de production.

/ This folder archives SQL dumps of the production Supabase schema.

## Rôle / Purpose

Disposer d'une version propre du schéma à restaurer si une migration
échoue ou corrompt l'état de la base. Les dumps servent de point de
récupération, pas de source de vérité — la source de vérité reste les
migrations versionnées dans `supabase/migrations/`.

/ To keep a clean schema snapshot for recovery if a migration fails or
corrupts the database state. Dumps are a recovery point, not a source of
truth — the source of truth remains the versioned migrations in
`supabase/migrations/`.

## Versionnement / Versioning

Les fichiers de dump (`*.sql`) **ne sont pas versionnés** dans git : ils
sont volumineux et changent à chaque export. Seul ce README est suivi.
Voir la règle correspondante dans `.gitignore` (`docs/db/*` +
`!docs/db/README.md`).

/ Dump files (`*.sql`) are **not tracked** in git: they are large and
change on every export. Only this README is tracked. See the matching
rule in `.gitignore`.

## Convention de nommage / Naming convention

`schema_<AAAA-MM-JJ>.sql` — date de l'export.

Commande de référence / Reference command :

```
supabase db dump -f docs/db/schema_AAAA-MM-JJ.sql --linked -s public,api,ingest
```
