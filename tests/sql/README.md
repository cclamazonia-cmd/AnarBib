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

**Fixtures — personas synthétiques fournies par `supabase/seed.sql`** :

| Persona | UUID | Rôle BLMF |
|---|---|---|
| Coordination de test | `11111111-1111-1111-1111-111111111111` | `coordenador` |
| Lectrice A | `33333333-3333-3333-3333-333333333333` | `reader` |
| Lecteur B | `44444444-4444-4444-4444-444444444444` | `reader` |
| Compte sans rôle | `22222222-2222-2222-2222-222222222222` | *(aucun)* |

> **Ces UUID sont synthétiques, et doivent le rester.** Jusqu'au 29/08/2026 ce
> tableau portait quatre identifiants *relevés en production le 11/05/2026*,
> avec le prénom de chaque personne en regard. Un UUID seul est pseudonyme ;
> accompagné d'une table de correspondance, il identifie une personne réelle —
> et trois tiers figuraient ainsi dans un dépôt public. **Une fixture relevée
> en production est une donnée de production : elle en garde le statut une fois
> recopiée dans un test.** Une suite qui a besoin d'un acteur le demande au
> seed ; elle ne le prélève jamais dans la base réelle.
>
> Depuis le 29/08/2026 la règle **ne dépend plus de la bonne volonté** : la sixième règle
> bloquante du hook `pre-commit` refuse, dans `tests/sql/`, tout UUID d'apparence réelle
> qui ne vient pas du seed (`DOC-FIXT-1` au REGISTRE). La liste blanche est **lue** dans
> `supabase/seed.sql`, pas recopiée : ajouter un acteur, c'est l'ajouter au seed.
>
> *Limite connue et assumée* : le seed contient un identifiant de production, celui de la
> bibliothèque BLMF, dont dépend la suite cotisation. C'est une bibliothèque, pas une
> personne, et son identité est publique au catalogue — mais la règle le tolère parce
> qu'il est au seed, pas parce qu'il serait synthétique.
>
> Le rôle `administrador` a disparu de ce tableau avec le même correctif : ce
> n'est pas un rôle de bibliothèque. Le CHECK de `user_library_memberships`
> n'admet que `reader`, `librarian` et `coordenador` ; l'administration **du
> réseau** vit dans `network_administrators` et n'a pas la main sur la
> circulation locale.

### `paquet_cotisation_tests.sql` (18 tests + 1 best-effort)

Tests d'acceptation du module **cotisations / gate de circulation** (Audit 360 #33).
Fixtures résolues **dynamiquement** (pas d'UUID codé en dur, qui se périment) : un
profil sans adhésion BLMF (sujet pilotable) + un coordenador actif de BLMF (acteur
staff). Tout est seedé dans la transaction et `ROLLBACK` à la fin.

**Couverture** :
- `fn_compute_membership_validity` (annual/rolling, calendar, lifetime) — 3
- `fn_is_loan_blocked_by_dues` (never_paid / up_to_date / expired / disabled) — 4
- `fn_membership_can_engage_circulation` (OK / no_active_membership / restricted / dues) — 4
- `fn_record_membership_payment` (anon, non-staff, montant < min, happy path staff) — 4
- Câblage du gate (trigger sur `emprestimos_v2` + `consultas_locais_v2`) + verrou
  anti-régression du fix §6.1 (`fn_v2_extend_core` revérifie l'éligibilité) — 3
- (best-effort) renouvellement self d'un membre restreint → `reason=restricted`
  (SKIP si aucun prêt ouvert en base).

### `paquet_renouvellement_granulaire_tests.sql` (9 tests + 1 best-effort)

Couvre les RPC de renouvellement **par item** du 29/05 (`api.renew_my_loan_item`,
`api.extend_loan_item_as_library`), absentes de `paquet19`. Existence + délégation
au cœur `fn_v2_extend_core` (héritage du recheck §6.1 + logique par-item), rejet
anonyme, `not_found` authentifié, ownership ; E2E best-effort sur un prêt ouvert.
Fixtures résolues dynamiquement.

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

Certains tests vérifient un comportement qui dépend de l'état de la base (ex. "rejeter le lecteur B sur emprunt de la lectrice A" demande qu'un emprunt de la lectrice A existe). Si les fixtures manquent, le test affiche `NOTICE: SKIP : ...` et ne fait pas échouer la suite. Ce n'est pas idéal pour une CI stricte mais c'est pragmatique pour BLMF (une seule biblio, données réelles).

Pour rendre ces tests plus robustes : créer des fixtures dans une transaction au début (BEGIN; INSERT INTO emprestimos_v2 ...; tests; ROLLBACK;).

## À ajouter plus tard (backlog)

- Tests pour les wrappers réservations (Phase 2 spec workflow réservation)
- Tests pour les RPCs `api.search_catalog_v1`, `api.library_circulation_stats`
- Tests pour les vues `api.my_*_v2` (RLS check)
- Migration vers pgTAP si on veut une vraie CI tests
