# Tests SQL — AnarBib

Tests d'acceptation pour les fonctions SQL et wrappers `api.*`.

**Convention** : ces tests ne sont PAS exécutés automatiquement par le flow CI (Woodpecker → `supabase db push`). Ils sont à lancer **manuellement** par le dev quand il veut valider une couche.

## Pourquoi pas dans `supabase/migrations/` ?

Les fichiers dans `supabase/migrations/` sont exécutés automatiquement par le flow CI à chaque push. Les tests d'acceptation ne sont pas idempotents : ils utilisent `ROLLBACK` (donc sans effet en prod) mais font des appels avec différents JWTs simulés, ce qui n'a rien à faire dans un flow de déploiement.

Garder les tests dans `tests/sql/` permet :
- De les lancer à la demande (Studio Supabase, psql local, etc.)
- De ne pas polluer les logs CI avec des dizaines de blocs `RAISE NOTICE`
- D'isoler les fixtures (UUIDs spécifiques BLMF) qui n'ont pas de sens en production multi-bib

## Fichiers

### `paquet19_loan_wrappers_tests.sql` (45 tests)

Tests d'acceptation des wrappers `api.*` créés au paquet 19 + helper `fn_check_loan_action` + helper `fn_get_loan_context`.

**Couverture** :
- Section 1 : helper `fn_check_loan_action` — 12 tests (matrice action × rôle × statut)
- Section 2 : helper `fn_get_loan_context` — 3 tests
- Section 3 : `api.create_loan_at_counter` — 5 tests
- Section 4 : `api.return_loan_total` + `api.return_loan_partial` — 8 tests
- Section 5 : `api.extend_loan_as_library` — 3 tests
- Section 6 : `api.renew_my_loan` (ownership crucial) — 5 tests
- Section 7 : `api.schedule_loan_return` + `api.clear_loan_return_schedule` — 6 tests
- Section 8 : `api.mark_loan_return_missed` — 3 tests

**Types de tests** :
- Rejet `auth` (28000) : appel anonyme
- Rejet `role` (42501) : mauvais rôle pour l'action
- Rejet `statut` : action sur emprunt clôturé
- Rejet `ownership` : lecteur agit sur emprunt d'autrui
- Happy path : wrapper passe les contrôles et délègue à la `fn_v2_*`

**Fixtures (UUIDs BLMF, vérifiés le 11/05/2026)** :

| Profil | UUID | Rôle BLMF |
|---|---|---|
| Xavier (staff) | `d6710372-e5e5-4608-800b-99a26817c677` | `administrador`+`coordenador` |
| Lívia (lecteur) | `366cdc4e-10e0-44ad-8554-a444bcf9607a` | `reader` |
| Arthur (lecteur) | `614d887d-4e8d-401d-a208-77c56a1cd5ea` | `reader` |
| Patricia (sans rôle) | `2a42b6bd-d159-4ee0-b66b-28a03062232b` | `null` |

## Comment lancer

### Option 1 : Supabase Studio (recommandé)

1. Aller sur le dashboard Supabase → SQL Editor
2. Coller le contenu de `paquet19_loan_wrappers_tests.sql`
3. Cliquer "Run"
4. Lire le log NOTICE : chaque test passe affiche `OK`, chaque échec lève une exception

### Option 2 : psql local

```bash
# Setup
export PGPASSWORD='<DB_PASSWORD>'
psql "host=db.uflwmikiyjfnikiphtcp.supabase.co user=postgres dbname=postgres port=5432" \
  -f tests/sql/paquet19_loan_wrappers_tests.sql
```

### Option 3 : Supabase CLI

```bash
supabase db execute -f tests/sql/paquet19_loan_wrappers_tests.sql --linked
```

## Lecture du résultat

Chaque bloc `DO $$` affiche :
- Une ligne `NOTICE: ─── TEST X.YZ : description ───`
- Soit `NOTICE: OK` (avec parfois plus de détails)
- Soit une `EXCEPTION` qui interrompt le test

Si le SQL global se termine sans erreur, **tous les tests sont passés**. Le bloc final affiche une synthèse.

## Tests "SKIP"

Certains tests vérifient un comportement qui dépend de l'état de la base (ex. "rejeter Arthur sur emprunt de Lívia" demande qu'un emprunt de Lívia existe). Si les fixtures manquent, le test affiche `NOTICE: SKIP : ...` et ne fait pas échouer la suite. Ce n'est pas idéal pour une CI stricte mais c'est pragmatique pour BLMF (une seule biblio, données réelles).

Pour rendre ces tests plus robustes : créer des fixtures dans une transaction au début (BEGIN; INSERT INTO emprestimos_v2 ...; tests; ROLLBACK;).

## À ajouter plus tard (backlog)

- Tests pour les wrappers réservations (Phase 2 spec workflow réservation)
- Tests pour les RPCs `api.search_catalog_v1`, `api.library_circulation_stats`
- Tests pour les vues `api.my_*_v2` (RLS check)
- Migration vers pgTAP si on veut une vraie CI tests
