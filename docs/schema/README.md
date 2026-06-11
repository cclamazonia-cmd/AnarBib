# `docs/schema/` — Snapshots de schéma (référence, PAS des migrations)

## Pourquoi ce dossier existe

Le dossier `supabase/migrations/` est **incrémental** : il ne contient **pas** le
schéma fondateur (tables `books`, `authors`, `profiles`, `libraries`, … + ~150
fonctions/vues), créé hors migrations sur le projet/prototype initial. Conséquence :
**`supabase db reset` ne reconstruit pas la base** depuis les seules migrations
(reproductibilité partielle). Cf. mémoire `catalog-mv-project-location` et le
backlog `docs/backlogs/ETAT-AVANCEMENT-multisessions.md`.

Ce dossier garde donc des **snapshots de référence** du schéma complet, pour :
- la **reprise après sinistre** (rebâtir la structure si la base est perdue) ;
- **comprendre** l'état réel du schéma sans fouiller 195 migrations.

## ⚠️ Ce ne sont PAS des migrations

Ces fichiers vivent dans `docs/schema/`, **jamais** dans `supabase/migrations/`.
Ils ne sont **pas** appliqués par `supabase db push` — c'est volontaire (les y
mettre casserait le CI : conflits « relation already exists »). **Référence only.**

## Snapshots

| Fichier | Date | Portée | Outil |
|---|---|---|---|
| `baseline_schema_2026-06-11.sql` | 2026-06-11 | schémas `public`, `api`, `ingest` (DDL seul) | `supabase db dump` |

## Régénérer un snapshot

Depuis un clone lié au projet (`supabase link --project-ref uflwmikiyjfnikiphtcp`,
PAT `SUPABASE_ACCESS_TOKEN` + mot de passe DB `SUPABASE_DB_PASSWORD`) :

```bash
supabase db dump -f docs/schema/baseline_schema_<AAAA-MM-JJ>.sql --schema public,api,ingest
```

## Ce que ça ne fait PAS (chantier futur)

Ceci ne **squashe** pas les migrations (rendre `supabase db reset` reproductible
de bout en bout). Ce serait un chantier dédié : baseline horodaté en tête de
`migrations/` + archivage des incréments + enregistrement dans `schema_migrations`.
Non urgent — la prod reste la source de vérité ; ce snapshot est l'assurance.
