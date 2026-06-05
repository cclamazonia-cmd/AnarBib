---
name: anarbib-sql
description: A appliquer pour TOUTE tache SQL/base de donnees d'AnarBib -- ecriture de migrations, modification de schema, fonctions, RLS, policies Storage, audit securite. Encode la doctrine migrations + securite. REGISTRE_decisions.md (regle de preseance) reste la source d'autorite ; en cas de doute, le consulter.

---

# Doctrine SQL / migrations AnarBib

## Le pipeline, pas l'editeur
- Les migrations DDL sont des **fichiers SQL horodates dans `supabase/migrations/`**, appliques par **Woodpecker** (`supabase db push --linked`) au push.
- **JAMAIS** coller du SQL dans le SQL Editor avant le push (-> "relation already exists").
- **JAMAIS** `apply_migration`, `create_branch`, `deploy_edge_function` via le MCP Supabase (l'horodatage = moment de l'appel -> mismatch fichier -> Woodpecker plante).
- `execute_sql` (MCP) = **inspection / lecture seule** uniquement.
- Si bug d'horodatage : `git mv` au bon horodatage, ou `migration repair --status applied` (non destructif).

## Horodatage
Strictement **superieur au max** present dans `supabase/migrations/`. Jamais "l'heure courante" en aveugle (des migrations anterieures ont parfois un horodatage dans le futur).

## Avant de modifier une table existante
Inspecter `pg_constraint` (pas seulement les colonnes) : les contraintes font partie du contrat.

## RLS et privileges
- Tables `public.*` : toujours **`ENABLE RLS` + policy** (meme `USING (false)`), jamais `DISABLE RLS`.
- REVOKE des fonctions privees : `FROM PUBLIC, anon, authenticated, service_role` (le `REVOKE FROM PUBLIC` seul est insuffisant -- `ALTER DEFAULT PRIVILEGES` Supabase re-accorde EXECUTE).
- Trigger non-DEFINER appelant une fonction SECURITY DEFINER revoquee : patcher `SECURITY DEFINER` + `search_path` **AVANT** le REVOKE.
- Verifier la RLS facon PostgREST : `SET LOCAL ROLE` + `SET LOCAL "request.jwt.claims"` (les deux). Wrap `EXCEPTION WHEN insufficient_privilege` pour les tables sans GRANT.

## DROP
Toujours `IF EXISTS`. Pour les fonctions/tables : **pas de CASCADE** -- si une dependance subsiste, le DROP echoue bruyamment (pipeline rouge) plutot que de casser en silence.

## Inspection / test
- `pg_get_functiondef(p.oid)` **sans troncation** pour les corps longs (sinon faux positifs sur les guards RBAC).
- Tester une fonction sans persistance : bloc `DO $test$ ... RAISE EXCEPTION 'RESULTATS ...', var ... $test$` (rollback auto + surface les valeurs).
- Doctrine ordering (#141.2.E) : `UPDATE` de la source narrative (workflow_note) **AVANT** la source d'etat (item_status, qui declenche les notifs).
- Fin de migration qui change le schema api/public : `NOTIFY pgrst, 'reload schema';`.

## Apres tout DDL
Lancer les advisors securite (`get_advisors` type security) et resumer par regle. Les ~200 fonctions DEFINER (anon publiques + wrappers RPC authenticated) sont l'architecture cible : ne pas chercher a faire baisser ce compteur, les documenter comme intentionnelles et durcies (search_path, validation).

## Cote application
- **RPC obligatoire** pour les actions DB (insert/update/delete, multi-tables, validations metier).
- `supabase.from()` autorise pour les **lectures simples** protegees par RLS.
- `supabase.storage.from()` = API native Storage, hors perimetre RPC.
