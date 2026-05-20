# Spec profils d'adoption v0.5 — Write-up final

**Date** : 19 mai 2026
**Statut** : version consolidée après bouclage paquet C
**Auteur·rice** : Xavier (session avec Claude)
**Remplace** : v0.4 (livrée 17/05/2026)

## Résumé exécutif

Cette version consolide la spec v0.4 avec les arbitrages doctrinaux pris pendant
le déploiement du paquet C (RLS+RPC+vues conditionnés par profil d'adoption).
Sept points sont raffinés ou clarifiés :

1. **Doctrine Q2 raffinée** : `libraries_public_signup_read` filtre aussi `isolated`
2. **Sémantique `fn_library_visible_to_caller` branche private** : inchangée mais documentée
3. **Contrainte CHECK §2.8** : déjà gardienne en BDD, confirmée
4. **Doctrine v2.1** : interdiction `ROLLBACK TO SAVEPOINT` dans DO block PL/pgSQL
5. **Pattern PEB triple défense** : RLS SELECT permissif (Q1) + RLS INSERT/UPDATE composite + RPC check
6. **Doctrine modèle de retour RPC** : `RAISE EXCEPTION` pour création, `RETURN jsonb` pour renouvellement
7. **Bouclage backend PEB** : trois lignes de défense, attente alignement frontend

## §1. Architecture des 4 axes orthogonaux (inchangé v0.4)

Voir spec v0.4 §1 pour la définition des 4 modes :
- `catalog_mode` : `local_only` | `network_published`
- `circulation_mode` : `off` | `informal` | `full_sigb`
- `network_mode` : `isolated` | `observer` | `federated`
- `governance_mode` : `informal` | `staff_roles` | `full_governance`

## §2. Sémantique des modes (raffinements v0.5)

### §2.4 `circulation_mode` (inchangé)

- `off` : aucune circulation possible. Le SIGB devient un catalogue figé.
- `informal` : circulation sans durées formelles (pas de politiques de prêt).
- `full_sigb` : circulation complète avec politiques.

**Doctrine confirmée v0.5** : les politiques de circulation (`library_circulation_policy_sets` et `_rules`) **n'ont de sens qu'en `full_sigb`**. En `informal`, les RLS C.3d filtrent à 0 ; en `off`, idem.

### §2.5 `network_mode` (raffinement v0.5)

- `isolated` : invisibilité réseau **inconditionnelle** (raffinement Q2)
- `observer` : voit le réseau, n'est pas vue par lui pour la circulation inter-bibs
- `federated` : participation pleine au réseau

**Doctrine raffinée Q2 v0.5** : `isolated` est inconditionnel, y compris quand `accepts_public_signup = true`. Une biblio isolated qui veut accueillir un·e nouveau·elle leitora·e doit passer en `observer` ou utiliser l'inscription manuelle par le staff. Précédemment (v0.4), `accepts_public_signup` court-circuitait le filtrage isolated dans `libraries_public_signup_read` — corrigé en C.3e.

### §2.8 Contrainte d'intégrité

**Confirmé en BDD prod** : la contrainte CHECK `chk_catalog_published_requires_network` est déjà en place :

```sql
catalog_mode = 'network_published' ⇒ network_mode ∈ {observer, federated}
```

Conséquence pratique pour les transitions : pour basculer en `isolated`, il faut **d'abord** mettre `catalog_mode = 'local_only'`. La contrainte refuse l'UPDATE direct.

## §3 à §8 (inchangés v0.4)

Voir spec v0.4.

## §9. Implémentation backend — État final paquet C bouclé

### §9.1 Helpers profils (livrés C.2, 19/05)

7 fonctions SECURITY DEFINER doctrine v2 :

| Helper | Sémantique |
|---|---|
| `fn_library_has_circulation(library_id)` | `circulation_mode <> 'off'` |
| `fn_library_has_full_sigb(library_id)` | `circulation_mode = 'full_sigb'` (strict) |
| `fn_library_publishes_catalog(library_id)` | `catalog_mode = 'network_published'` |
| `fn_library_is_federated(library_id)` | `network_mode = 'federated'` (strict) |
| `fn_library_uses_governance(library_id)` | `governance_mode = 'full_governance'` (strict) |
| `fn_library_has_staff_roles(library_id)` | `governance_mode <> 'informal'` |
| `fn_peb_authorized(lender_id, borrower_id)` | composite C.3c : circulation + federated des deux côtés |

**Extension v0.5** : `fn_library_visible_to_caller(library_id)` étendu pour inclure
`network_mode <> 'isolated'` sur les branches `public` et `network`.

### §9.2 Sémantique branche `private` de `fn_library_visible_to_caller`

**Clarification doctrinale v0.5** : la branche private du helper exige strictement
`visibility_level = 'private'` ET membre. Ne s'applique pas à une biblio en
`visibility_level = 'public' + network_mode = 'isolated'` — dans ce cas, même
un membre ne voit pas sa biblio via cette policy (la branche public est bloquée
par isolated, la branche private exige visibility_level=private).

**Doctrine retenue** : c'est cohérent avec §2.5 strict. Si un·e responsable
de biblio veut conserver la visibilité pour ses membres en passant isolated,
illia doit **d'abord** changer `visibility_level` à `private`, puis basculer
`network_mode` à `isolated`. C'est un choix volontaire en deux temps.

### §9.3 RLS conditionnées (livrées C.3, 19/05)

**22 RLS patchées sur 18 tables** :

| Table | RLS patchées | Helper utilisé |
|---|---|---|
| `reservas_v2` (C.3a) | 5 RLS | `fn_library_has_circulation` |
| `emprestimos_v2` (C.3b) | 1 SELECT | `fn_library_has_circulation` |
| `consultas_locais_v2` (C.3b) | 1 SELECT | `fn_library_has_circulation` |
| `interlibrary_loans_v2` (C.3b) | 1 SELECT permissive (Q1) | `fn_library_has_circulation` (OR clôture) |
| `interlibrary_loans_v2` (C.3c) | 2 INSERT/UPDATE | `fn_peb_authorized` composite |
| `library_circulation_policy_sets` (C.3d) | 5 RLS | `fn_library_has_full_sigb` |
| `library_circulation_policy_rules` (C.3d) | 5 RLS (redondance défensive Q3) | `fn_library_has_full_sigb` |
| `libraries` (C.3e) | 2 RLS (public_read + signup_read) | helper + `network_mode <> 'isolated'` |

**Arbitrage Q1** : SELECT PEB reste permissive pour permettre la clôture des PEB
en cours même si une bib bascule en `off`. INSERT/UPDATE strictes via composite.

**Arbitrage Q3** : redondance défensive sur les RLS rules (filtre dans le EXISTS
en plus de l'héritage via policy_sets).

### §9.4 RPC métier (livrées C.4a et C.4b, 19/05)

**6 RPC SECURITY DEFINER patchées** :

| RPC | Check | Modèle de retour |
|---|---|---|
| `fn_v2_create_emprestimo_by_holdings` | `fn_library_has_circulation(v_actor.library_id)` | RAISE EXCEPTION + hint |
| `fn_v2_create_reserva_by_holdings` | `fn_library_has_circulation(v_batch_library_id)` | RAISE EXCEPTION + hint |
| `fn_v2_create_consulta_local_by_holdings` | `fn_library_has_circulation(v_batch_library_id)` | RAISE EXCEPTION + hint |
| `fn_v2_create_emprestimo_interbibliotecas` | `fn_peb_authorized(lender, borrower)` | RAISE EXCEPTION + hint |
| `fn_renew_my_loan` | `fn_library_has_circulation(v_header.library_id)` | RETURN jsonb {ok:false, reason:'circulation_disabled'} |
| `fn_v2_extend_emprestimo_once` | idem | idem |

**Doctrine v0.5 modèles de retour** : les RPC de création utilisent `RAISE EXCEPTION`
avec hint i18n (style existant). Les RPC de renouvellement utilisent
`RETURN jsonb {ok, reason}` (style existant). On respecte le pattern de chaque fonction.

**Hints i18n générés** (à traduire frontend, paquet C.4c) :
- `error.library.circulation_disabled` (×6 locales militantes)
- `error.library.peb_not_authorized` (×6 locales militantes)

### §9.5 Vues et MV (livrées C.5, 19/05)

| Objet | Patch | Sémantique |
|---|---|---|
| `api.libraries_public_v1` | RIEN (utilise déjà `fn_library_visible_to_caller`) | hérite C.2 extension |
| `api.network_overview` | `network_mode <> 'isolated'` sur `libraries_active` | compteur réseau strict |
| `mv_books_catalog_list_network_v1` | `catalog_mode = 'network_published' AND network_mode <> 'isolated'` au CTE holdings_with_lib | catalogue federé strict |

**Décision doctrinale v0.5 pour `network_overview`** : seul `libraries_active` est
filtré par isolated. Les autres compteurs (books, exemplares, loans) restent
globaux SIGB pour ne pas perdre d'info — ils représentent l'activité de la plateforme,
pas du réseau seul. Si une biblio bascule isolated, ses transactions restent
visibles dans les compteurs de fonctionnement.

**MV `mv_books_catalog_list_network_v1`** : la doctrine spec §9.3 est appliquée
strictement : seules les biblios qui ont **explicitement** publié leur catalogue
(`catalog_mode = network_published`) ET qui ne sont pas isolated apparaissent.
Une biblio en `visibility_level = public` mais `catalog_mode = local_only` garde
son catalogue privé du réseau.

### §9.6 Triple défense PEB (raffinement architectural v0.5)

Le sujet PEB illustre la **doctrine de défense en profondeur** mise en place :

1. **RLS SELECT permissive** (C.3b) : permet la lecture pour clôture propre Q1
2. **RLS INSERT/UPDATE composite stricte** (C.3c) : `fn_peb_authorized` exige
   circulation+federated des deux côtés
3. **RPC SECURITY DEFINER avec check** (C.4a.1) : même condition, plus message
   d'erreur i18n explicite (évite l'erreur RLS opaque côté frontend)

C'est la **première** application complète de cette doctrine. Toutes les autres
transactions (emprestimo, reserva, consulta) bénéficient des couches 1 et 3 ;
la couche 2 (composite) n'existe que pour PEB qui implique deux biblios.

## §10. Doctrine création objets backend v2.1

**Mise à jour 19/05/2026** (issue de la session C) :

**Règles v2 (rappel du chantier #150)** :
- SECURITY DEFINER + SET search_path = public, pg_temp
- REVOKE EXECUTE FROM PUBLIC, anon, authenticated, service_role
- GRANT EXECUTE TO authenticated uniquement
- DO block fail-fast en fin de migration

**Ajout v2.1 — interdiction SAVEPOINT** :
Les `ROLLBACK TO SAVEPOINT` ne sont **PAS supportés dans un DO block PL/pgSQL**.
Pour tester un état temporaire dans une migration, utiliser une **transaction
séparée hors migration** (via `execute_sql` MCP par exemple), ou faire un test
indirect après commit.

## §11. Décisions reportées au backlog (post-spec)

| Item | Raison du report | Sous-paquet futur |
|---|---|---|
| `error.library.full_sigb_required` (i18n) | aucun cas d'usage immédiat — créé en C.4 si besoin | C.4c+ |
| `error.library.network_isolated` (i18n) | idem | C.4c+ |
| Tests fumée locales restantes (es/en/it/de) | non bloquant fonctionnellement | post-C.4c |
| Alignement message frontend PEB | sera traité dans le chantier frontend dédié PEB | indépendant |

## §12. Bilan paquet C

| Critère | Avant paquet C | Après paquet C bouclé |
|---|---|---|
| RLS conditionnées par profil | 0/22 | 22/22 ✅ |
| Helpers profil | 0 | 7 ✅ |
| RPC métier avec check | 0/6 | 6/6 ✅ |
| Vues/MV filtrées | 0/3 | 3/3 ✅ |
| Clés i18n d'erreur | 0/12 | spec livrée, à intégrer frontend |
| Migrations livrées | — | 11 (timestamps 20260519100000 → 200000) |
| Doctrines actées | — | Q1, Q2 raffinée, Q3, Q4, Q5, Q6 + triple défense PEB + v2.1 |

**Toutes les 4 axes orthogonaux sont désormais effectivement contraignants côté
backend** : changer un mode `circulation_mode`, `network_mode`, `catalog_mode`,
ou `governance_mode` produit immédiatement les comportements doctrinaux attendus
dans les RLS, RPC, et vues. Le frontend n'a plus qu'à consommer les hints i18n
(C.4c en cours).

## Annexes

### Migrations de la session 19/05/2026

| Timestamp | Sous-paquet | Description |
|---|---|---|
| 20260519100000 | C.2 | 7 helpers + extension fn_library_visible_to_caller |
| 20260519110000 | C.3a | 5 RLS reservas_v2 |
| 20260519120000 | C.3b | 3 RLS SELECT prêts/consultas/PEB |
| 20260519130000 | C.3c | helper fn_peb_authorized + 2 RLS PEB INSERT/UPDATE |
| 20260519140000 | C.3d | 10 RLS policy_sets+rules |
| 20260519150000 | C.3e | 2 RLS libraries (public_read + signup_read) |
| 20260519160000 | C.4a.1 | RPC fn_v2_create_emprestimo_interbibliotecas |
| 20260519170000 | C.4a.2-4 | 3 RPC création (emprestimo+reserva+consulta) |
| 20260519180000 | C.4b | 2 RPC renouvellement (renew_my_loan + extend_once) |
| 20260519200000 | C.5 | network_overview + MV catalog + vue dépendante |

### Fichiers livrés

- 11 migrations SQL (cf. tableau ci-dessus)
- 11 scripts PowerShell `Push-Paquet*.ps1`
- 1 spec i18n `paquetC4c_spec_i18n_keys.md`
- 1 audit RLS initial `paquetC1_audit_rls.md`
- 1 spec consolidée `spec-profils-bibliotheque-v0.5.md` (ce document)

### Doctrines de session à propager dans le Grand Livre Blanc v14+

1. Triple défense PEB (RLS SELECT permissif + RLS INSERT/UPDATE composite + RPC check)
2. Q2 raffinée : `isolated` filtre `accepts_public_signup`
3. v2.1 : interdiction `ROLLBACK TO SAVEPOINT` dans DO block
4. Pattern d'injection pour modification de RPC : récupération `pg_get_functiondef`,
   redéclaration intégrale avec check ajouté, dry-run par fonction
5. Test PostgREST simulé : `SET LOCAL ROLE` + `SET LOCAL "request.jwt.claims"`
   toujours combinés (jamais l'un sans l'autre)
6. Contrainte CHECK §2.8 active depuis avant cette session — confirmée gardienne
