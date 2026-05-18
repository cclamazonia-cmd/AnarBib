# Spec profils d'adoption v0.6 - Write-up final paquet D

**Date** : 19 mai 2026 (UTC+2 ; jour ouvre 18 mai chez Xavier)
**Statut** : version consolidee apres bouclage paquet D complet
**Auteur** : Xavier (session avec Claude)
**Remplace** : v0.5 (livree 19/05/2026 apres bouclage paquet C)

## Resume executif

Cette version consolide la spec v0.5 avec les arbitrages doctrinaux pris pendant
le deploiement du paquet D (mecanique d'archivage et de masquage des transactions
lors des transitions de profil type 4).

Sept points sont raffines, clarifies ou ajoutes par rapport a la v0.5 :

1. **Doctrine v2.2 (CREATE OR REPLACE VIEW)** validee sur 17 vues patches en
   D.3 + D.4 + D.5 : les grants sont preserves automatiquement
2. **Doctrine D.6 point d'orgue** : archivage dans `fn_execute_*`, pas dans
   `fn_propose_*`
3. **Doctrine typage UNION ALL** : auditer les types des PK avant tout UNION
   inter-tables ; cast `::text` si heterogene
4. **Doctrine 90j hardcode** : politique conservatrice par defaut pour le
   desarchivage manuel, ajustable plus tard via colonne
   `libraries.unarchive_grace_days`
5. **Doctrine cotisations historiques** : non concernees par la couche masquage
   D.4 (tracabilite comptable preservee meme en `circulation_mode = 'off'`)
6. **Doctrine PEB rapports** : `interlibrary_loans_reports_ui` filtre uniquement
   par `archived_at IS NULL` (D.3), pas par `circulation_mode` -- la
   coordination inter-bibs doit pouvoir consulter les PEB passes meme si une
   biblio se retire
7. **Inventaire reel des vues d'historique** : la spec v0.4 en mentionnait 2,
   l'audit prod a revele 6. Les 6 sont patches en D.4.

## Sections 1 a 8 (inchangees v0.4)

Voir spec v0.4.

## Sections 9.1 a 9.6 (inchangees v0.5)

Voir spec v0.5 pour le bilan paquet C bouclé.

## Section 9.7 -- Implementation backend paquet D bouclé

### 9.7.1 Architecture des deux couches

Le paquet D distingue **deux mecaniques** complementaires (spec v0.4 section 9.4) :

**Couche archivage** (D.1, D.2, D.3) :
- Marque `archived_at = now()` + `archive_reason` sur les transactions
  vivantes lors d'une transition de profil type 4
- Filtre `WHERE archived_at IS NULL` sur les vues actives -> les archives
  disparaissent des UIs courantes
- Reversible via les helpers `fn_unarchive_library_circulation` (revocation
  pendant carence) et `fn_unarchive_transaction` (desarchivage manuel administrador-a)

**Couche masquage** (D.4) :
- Pas de modification de donnees
- Filtre `circulation_mode <> 'off'` dans les vues d'historique
- Si une biblio bascule en `off`, son historique disparait des UIs courantes
- Si elle revient a `informal` ou `full_sigb`, l'historique REAPPARAIT
  automatiquement (purement bascule de visibilite)

### 9.7.2 Infrastructure (livree D.1, 19/05)

5 tables transactionnelles patches :

| Table | Colonnes ajoutees | Indexes partiels |
|---|---|---|
| `emprestimos_v2` | `archived_at` + `archive_reason` | 2 (active + archived) |
| `reservas_v2` | idem | 2 |
| `consultas_locais_v2` | idem | 2 |
| `interlibrary_loans_v2` | idem | 3 (lender_active + borrower_active + archived) |
| `membership_payments` | idem | 2 |

**Contraintes CHECK** :
- `archive_reason IN ('profile_transition', 'admin_manual', 'system_cleanup')`
- `(archived_at IS NULL) = (archive_reason IS NULL)` (consistency)

**Donnees prod au moment du paquet** : aucune transaction vivante (29 emp + 14
res + 28 con tous encerrados ; 0 ILL ; 1 cotisation BLMF active). Le paquet
D.1 est donc sans risque sur les donnees existantes : `archived_at` reste
NULL partout au start.

### 9.7.3 Helpers d'archivage (livres D.2, 19/05)

3 fonctions SECURITY DEFINER doctrine v2 (REVOKE PUBLIC/anon/authenticated/service_role, GRANT postgres only) :

| Helper | Role | Tables impactees |
|---|---|---|
| `fn_archive_library_circulation(library_id, proposal_id)` | Archive transactions vivantes lors d'une transition type 4 | emp + res + con + ill |
| `fn_unarchive_library_circulation(library_id, proposal_id)` | Restaure les archives `profile_transition` lors d'une revocation pendant carence | idem |
| `fn_archive_library_cotisations(library_id, proposal_id)` | Archive cotisations en cours lors de `full_sigb -> informal` | membership_payments |

**Particularite ILL** : la table n'a pas de colonne `library_id` directe. On
filtre par `(lender_library_id = p_library_id OR borrower_library_id = p_library_id)`.
Une biblio qui passe en off voit ses PEB archives en tant que lender ET en
tant que borrower -- coherent avec la doctrine "elle sort fonctionnellement
du reseau de PEB".

**Idempotence** : tous les helpers filtrent `archived_at IS NULL` au moment
d'archiver, et `archived_at IS NOT NULL AND archive_reason = 'profile_transition'`
au moment de desarchiver. Multiple appels = no-op apres le premier.

**Retour** : `jsonb` avec `ok`, `library_id`, `proposal_id`, `archive_reason`,
`archived_at`, `counts` par table.

### 9.7.4 Patch des vues actives (livre D.3, 19/05)

11 vues patches avec `CREATE OR REPLACE VIEW` (preservation grants -- doctrine v2.2) :

| Vue | Filtre ajoute |
|---|---|
| `api.consulta_itens_followup_ui` | `c.archived_at IS NULL` |
| `api.emprestimo_itens_painel_ui` | `e.archived_at IS NULL` |
| `api.emprestimo_itens_ui` | `e.archived_at IS NULL` |
| `api.interlibrary_loan_items_ui` | `h.archived_at IS NULL` |
| `api.interlibrary_loans_painel_ui` | `h.archived_at IS NULL` |
| `api.interlibrary_loans_reports_ui` | `h.archived_at IS NULL` |
| `api.library_circulation_stats` | 7 sous-requetes patches (loans_open, loans_overdue, loans_returned_7d, loans_created_7d/30d, reservations_active, reservations_30d, consultations_active, top_books_90d) |
| `api.my_loans_renewal_status_v1` | `e.archived_at IS NULL` + `r.archived_at IS NULL` (sous-requete reserved_by_other) |
| `api.reserva_itens_followup_ui` | `r.archived_at IS NULL` |
| `api.staff_loans_renewal_status_v1` | idem D.8 |
| `public.v_active_memberships` | `mp.archived_at IS NULL` dans CTE last_payment |

**Verification post-deploiement** : 11/11 vues contiennent le filtre, 10/10 grants
authenticated SELECT preserves (1 vue dans public n'utilise pas le pattern api).

### 9.7.5 Patch des vues d'historique (livre D.4, 19/05)

**Decouverte D.4** : la spec v0.4 mentionnait 2 vues d'historique a patcher
(`my_loans_history_v1`, `painel_loans_history_v1`). L'audit prod a revele
**6 vues**. Toutes patches :

| Vue | Cote | Source |
|---|---|---|
| `api.my_consultas_history_v2` | Lecteur | cascade via `consulta_itens_followup_ui` |
| `api.my_loans_history_v1` | Lecteur | `emprestimos_v2` direct |
| `api.my_reservations_history_v2` | Lecteur | cascade via `reserva_itens_followup_ui` |
| `api.painel_consultas_history_v1` | Staff | cascade via `consulta_itens_followup_ui` |
| `api.painel_loans_history_v1` | Staff | `emprestimos_v2` direct |
| `api.painel_reservations_history_v1` | Staff | cascade via `reserva_itens_followup_ui` |

**Filtre ajoute** : `EXISTS (SELECT 1 FROM libraries lib WHERE lib.id = ... AND lib.circulation_mode <> 'off')`.

**Decisions doctrinales** :
- **Cotisations historiques** : NON masquees. `v_active_memberships` reste
  inchangee niveau circulation_mode (tracabilite comptable preservee). Voir
  spec section 9.4 : "cohérence comptable : cotisations historiques ne sont
  pas masquees".
- **PEB rapports** : NON masques. `interlibrary_loans_reports_ui` filtre
  uniquement par `archived_at IS NULL` (D.3). La coordination inter-bibs doit
  pouvoir consulter les PEB passes meme si une biblio s'est retiree du reseau.

**Verification** : 29 emp historiques BLMF restent visibles dans
`painel_loans_history_v1` (BLMF en `full_sigb`, filtre passe).

### 9.7.6 Desarchivage manuel (livre D.5, 19/05)

**Livrables** :
- Table `public.library_unarchive_log` : audit immutable, RLS staff lecteur,
  REVOKE writes (passage obligatoire par la RPC)
- Helper `fn_check_unarchive_eligibility(table_name text, record_id text)` :
  white-list + check 90j + check circulation_mode <> 'off'
- RPC publique `fn_unarchive_transaction(table_name text, record_id text, motivation text)` :
  SECURITY DEFINER + GRANT EXECUTE authenticated, 4 garde-fous + i18n
- Vue `api.library_archived_transactions` : UNION ALL des 5 tables, accessible
  staff via RLS implicite (security_invoker = true)

**Doctrine typage `text`** (apprise D.5 v1 -> v2) :

Les 5 tables transactionnelles ont des PK heterogenes :
- 4 tables `bigint` (emprestimos, reservas, consultas, interlibrary_loans)
- 1 table `uuid` (membership_payments)

`UNION ALL` exige des types identiques. Solution adoptee :
- Table `library_unarchive_log.record_id` : `text`
- Vue `library_archived_transactions.record_id` : cast `id::text` partout
- RPC signature : `p_record_id text`
- Cast interne au runtime selon la table cible :
  ```sql
  IF p_table_name IN ('emprestimos_v2', ...) THEN
    v_record_bigint := p_record_id::bigint;
  ELSE
    v_record_uuid := p_record_id::uuid;
  END IF;
  ```
- Gestion d'erreur sur cast invalide : `reason = 'invalid_record_id_format'`

**Doctrine 90j hardcode** : pour les transactions avec echeance theorique
(`emprestimos_v2.due_at`, `interlibrary_loans_v2.due_date`), refus du
desarchivage si l'echeance est depassee de plus de 90 jours. Ajustable
plus tard via colonne `libraries.unarchive_grace_days` si besoin (cf.
backlog v0.6).

**Garde-fous RPC** (4) :
1. Authentification : `auth.uid()` non-NULL
2. Motivation >= 5 caracteres
3. Eligibilite (via helper) : table whitelist + record existe + archive +
   biblio en circulation + age <= 90j
4. Caller est staff actif (`librarian` ou `coordenador`) de la biblio cible

**Doctrine #141.2.E** appliquee : INSERT audit log AVANT UPDATE etat (la
source de verite narrative).

### 9.7.7 Connexion paquet B <-> paquet D (livre D.6, 19/05, point d'orgue)

**2 modifications** :

**`fn_propose_library_profile_change`** :
- Retrait du `RAISE EXCEPTION 'PROPOSE_TYPE_4_REQUIRES_PACKAGE_D'`
- Les transitions type 4 sont maintenant **proposables** comme les autres
  (vote selon governance_mode)

**`fn_execute_library_profile_change`** :
- Ajout de 2 hooks d'archivage **apres** `UPDATE libraries` (etape 2) et
  **avant** `UPDATE proposal status='completed'` (etape 3)
- Cas 1 : `circulation_mode -> 'off'` -> appel `fn_archive_library_circulation`
- Cas 2 : `circulation_mode: 'full_sigb' -> 'informal'` -> appel
  `fn_archive_library_cotisations`
- Retour `jsonb` enrichi : ajout du champ `archive_result` (NULL si pas
  d'archivage applique)

**Doctrine d'ordonnancement** :
- L'archivage vient APRES l'`UPDATE libraries` car il depend de la nouvelle
  valeur de circulation_mode (les helpers verifient implicitement que la
  biblio est dans le bon etat post-bascule).
- Ce n'est pas une violation de la doctrine #141.2.E (NARRATIVE avant ETAT)
  car l'archivage est un **effet de bord systeme**, pas une narrative en soi.
  La narrative reste l'INSERT `library_profile_history` qui se fait en etape 1.

**Doctrine point d'orgue** : l'archivage se fait **dans `fn_execute_*`, jamais
dans `fn_propose_*`**. C'est coherent avec le cycle de vie d'une proposition
(open -> accepted -> grace_period -> completed). L'archivage doit etre
contemporain de la bascule effective de l'etat, pas de la proposition.

## Section 10 -- Doctrine creation objets backend v2.2 (MAJ)

**Mise a jour 19/05/2026 (issue de l'hotfix C.5 + paquets D.3-D.4-D.5)** :

**Regles v2 (rappel)** :
- SECURITY DEFINER + SET search_path = public, pg_temp
- REVOKE EXECUTE FROM PUBLIC, anon, authenticated, service_role
- GRANT EXECUTE TO authenticated uniquement (ou postgres pour helpers internes)
- DO block fail-fast en fin de migration

**Regles v2.1 (rappel)** : interdiction `ROLLBACK TO SAVEPOINT` dans DO block.

**Ajout v2.2 -- DROP+CREATE vs CREATE OR REPLACE** :

`DROP VIEW + CREATE VIEW` ne preserve PAS les GRANTs. Bug induit en C.5 :
catalogue et dashboard reseau ont perdu leurs grants `authenticated SELECT`
-> 503 sur les vues -> regression UX catastrophique.

**Regle** : prefer `CREATE OR REPLACE VIEW` quand la signature des colonnes
ne change pas. Les grants sont alors automatiquement preserves.

Si DROP+CREATE est obligatoire (changement de signature) :
1. Capturer les grants AVANT le DROP via `information_schema.role_table_grants`
2. Restaurer explicitement les grants APRES le CREATE
3. Inclure verification dans DO block fail-fast

**Validation pratique** : doctrine appliquee en D.3 (11 vues), D.4 (6 vues),
D.5 (4 objets dont 1 vue). Resultat : **17/17 vues conservent leurs grants**.

## Section 10 bis -- Doctrine typage UNION ALL (nouvelle v0.6)

Apprise lors du rollback D.5 v1 (erreur SQLSTATE 42804) :

`UNION ALL` exige que toutes les colonnes a la meme position aient le **meme
type**. PostgreSQL ne fait pas de conversion implicite (sauf cas triviaux
comme integer/bigint dans certains contextes).

**Cas typique en SIGB** : tables transactionnelles heterogenes (4 tables
`bigint`, 1 table `uuid` pour les PK).

**Procedure d'audit avant tout UNION inter-tables** :
1. `SELECT table_name, column_name, data_type FROM information_schema.columns WHERE ...`
2. Si types heterogenes : choisir un type cible commun (`text` est le plus
   permissif, accepte tout via cast `::text`)
3. Cast explicite `id::text`, `due_at::text`, etc. dans chaque branche du UNION
4. Adapter les fonctions et tables consommatrices pour utiliser le type cible

**Pattern de cast au runtime** dans les RPC (post-D.5) :
```sql
IF p_table_name IN ('emprestimos_v2', 'reservas_v2', 'consultas_locais_v2', 'interlibrary_loans_v2') THEN
  v_record_bigint := p_record_id::bigint;
ELSIF p_table_name = 'membership_payments' THEN
  v_record_uuid := p_record_id::uuid;
END IF;
```

Gestion d'erreur :
```sql
BEGIN
  v_record_bigint := p_record_id::bigint;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN jsonb_build_object('ok', false, 'reason', 'invalid_record_id_format');
END;
```

## Section 11 -- Backlog post-paquet D (mise a jour v0.6)

Items deplaces du backlog :
- ~~"Mecanique d'archivage paquet D"~~ -> bouclee 19/05
- ~~"Connexion paquet B <-> paquet D"~~ -> bouclee 19/05 (D.6)

Items conserves / ajoutes en v0.6 :

| Item | Source | Statut |
|---|---|---|
| 11.1 Revocation pendant carence | Issu de v0.3 | Reportee (necessite RPC dediee `fn_revoke_profile_proposal` + appel `fn_unarchive_library_circulation`) |
| 11.2 Gel des jobs pendant carence | Issu de v0.3 section 4.6 | Reporte (necessite analyse des cron/jobs prod) |
| 11.3 `libraries.unarchive_grace_days` configurable | Issu de D.5 doctrine 90j | Reporte (90j hardcode suffit pour BLMF+BTL) |
| 11.4 Tests fumee transitions type 4 | Issu D.6 | A faire en session fraiche sur biblio test |
| 11.5 Front-end paquet E | Spec v0.4 section 9.5 | Pret a demarrer |
| 11.6 Module PEB frontend (chantier reporte) | Diagnostic 19/05 | Documenté `docs/decisions/CHANTIER_peb_frontend_diagnostic_2026-05-19.md` |
| 11.7 Onboarding refondu paquet F | Spec v0.4 section 9.6 | Independant, peut etre fait en parallele de E |
| 11.8 Bandeau biblios existantes paquet G | Spec v0.4 section 9.7 | Final, depend de A-F |

## Section 12 -- Bilan paquet D

| Critere | Avant paquet D | Apres paquet D bouclé |
|---|---|---|
| Tables transactionnelles avec archived_at | 0/5 | 5/5 ✅ |
| Helpers archivage | 0/3 | 3/3 ✅ |
| Vues actives filtrees | 0/11 | 11/11 ✅ |
| Vues historique filtrees | 0/6 | 6/6 ✅ |
| Table audit `library_unarchive_log` | absente | livree ✅ |
| RPC desarchivage manuel | absente | livree ✅ |
| Vue listing archives | absente | livree ✅ |
| Transitions type 4 fonctionnelles | bloquees | ✅ |
| Migrations livrees paquet D | -- | 6 (D.1 a D.6) |
| Doctrines actees | -- | v2.2 + typage UNION ALL + 90j + point d'orgue |

**Le chantier profils d'adoption est desormais entierement fonctionnel cote
backend**. Une biblio peut maintenant proposer une transition type 4
(`circulation_mode -> off` ou `full_sigb -> informal`) qui passera par le
processus normal de vote selon governance_mode, et l'execution declenchera
automatiquement l'archivage approprié.

**Reste a faire** : paquets E (frontend painel adaptatif), F (onboarding
refondu), G (deploiement final). Et la verification fumee d'une transition
type 4 reelle.

## Annexes

### Migrations du paquet D (6 sous-paquets)

| Timestamp | Sous-paquet | Description |
|---|---|---|
| 20260519210000 | D.1 | Colonnes archive_at + archive_reason + CHECK + 11 indexes partiels sur 5 tables |
| 20260519220000 | D.2 | 3 helpers SECURITY DEFINER (archive/unarchive circulation + archive cotisations) |
| 20260519230000 | D.3 | Patch 11 vues actives avec filtre `archived_at IS NULL` |
| 20260519240000 | D.4 | Patch 6 vues historique avec filtre `circulation_mode <> 'off'` |
| 20260519250000 | D.5 | Table library_unarchive_log + helper fn_check_unarchive_eligibility + RPC fn_unarchive_transaction + vue api.library_archived_transactions (record_id text apres fix v2) |
| 20260519260000 | D.6 | Retrait refus type 4 dans fn_propose + hooks fn_archive_library_circulation/cotisations dans fn_execute (point d'orgue) |

### Fichiers livres session 19/05

- 6 migrations SQL (cf. tableau ci-dessus) + 1 hotfix C.5 (20260519205000)
- 7 scripts PowerShell `Push-Paquet*.ps1` + `Push-HotfixC5.ps1`
- 1 spec consolidee `spec-profils-bibliotheque-v0.6.md` (ce document)
- 1 bilan de session `BILAN_session_19_mai_2026_paquets_C_D.md` (separe)

### Doctrines de session a propager dans le Grand Livre Blanc v14+

1. **v2.2 -- CREATE OR REPLACE VIEW** preserve les grants. Validee sur 17 vues.
2. **Typage UNION ALL** : auditer les PK avant, cast `::text` si heterogene.
3. **90j hardcode desarchivage** : politique conservatrice par defaut.
4. **D.6 point d'orgue** : archivage dans `fn_execute_*`, pas dans `fn_propose_*`.
5. **Outage Codeberg** : < 30% uptime = stop, pas force. Mais retenter periodiquement.
6. **Transactions atomiques** : BEGIN..COMMIT, rollback complet propre en cas d'erreur.
7. **PEB rapports non masques par circulation_mode** : coordination inter-bibs preservee.
8. **Cotisations historiques non masquees** : tracabilite comptable preservee.

### Statistiques

- Date : 18-19 mai 2026
- Migrations livrees session totale (C + hotfix + D) : 17
- Vues patches (sans perte de grant) : 17
- Fonctions SECURITY DEFINER ajoutees ou modifiees : 8
- Doctrines actees : 8
- Regressions diagnostiquees + resolues en cours de session : 2 (catalogue C.5, typage UNION D.5)
- Pannes Codeberg traversees : 3 (504, panne ~1h Woodpecker, 503)
- Builds Woodpecker verts : 16 dans la journee
- Decisions de stop : 2 (puis 2 retours bonus)
