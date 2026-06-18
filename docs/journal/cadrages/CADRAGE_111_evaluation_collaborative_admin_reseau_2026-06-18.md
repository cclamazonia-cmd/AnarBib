# CADRAGE — #111 · Évaluation collaborative des demandes d'adhésion par les admins réseau

> **Date** : 2026-06-18
> **Session** : Audit 360 — morceaux rouges (ONBO-Q13 + #111)
> **Statut** : cadrage d'implémentation — *aucun code poussé*. Prêt à coder lot par lot.
> **Réf. design (le QUOI/POURQUOI)** : `docs/specs/spec-onboarding-biblioteca-v2.0.md` §2.7, §3, §4, §5 ; `docs/specs/spec-administrateur-reseau.md v0.4` (cooptation unanime — précédent à calquer) ; REGISTRE #111.
> **Ce document = le COMMENT** : schéma exact aligné au baseline, RPC, triggers, Edge Function, écrans, i18n, tests, séquençage.

---

## 0. TL;DR

Le **mode dégradé seul-admin est déjà live** (un·e admin approuve via `RedePage` → `api.fn_approve_library_request`, qui provisionne ; corrigé le 18/06, cf. ONBO-Q13). #111 ajoute, **par-dessus et sans le casser**, le **workflow collaboratif** qui s'active quand le réseau a **≥ 3 admins actifs** (cas attendu à Bologne, sept. 2026) : un·e admin **propose** une décision (accept/refus), les autres **votent**, l'**unanimité** confirme et déclenche le provisioning (accept) ou le refus. Plus : **commentaires** internes, **messages** avec la solicitante, **« proposer un échange »**, et **digest proactif**.

**Principe directeur** : calquer **trait pour trait** le workflow de **cooptation des admins réseau** (tables `network_administrator_cooptation_votes`, fonctions `fn_network_admin_propose_cooptation` / `fn_network_admin_vote_cooptation`, cron `fn_cron_cooptation_send_reminders`). Même grammaire = cohérence + zéro surprise de gouvernance.

**3 lots, 3 cycles de push validés** (chacun comme ONBO-Q13 : migration → test SQL local sur image CI → push → pipeline vert → lot suivant).

---

## 1. Précédent à calquer (déjà en prod)

| Cooptation admin (existant) | Équivalent #111 (à créer) |
|---|---|
| `network_administrator_cooptation_proposals` (proposition) | *(pas de table proposition séparée : la demande EST la proposition ; on pose `proposed_*` sur `library_requests`)* |
| `network_administrator_cooptation_votes` (vote, PK (proposal, voter), `disclose_identity` NOT NULL, rationale ≥20 si against) | `library_request_votes` (PK (request_id, voter_admin_id), idem) |
| `fn_network_admin_propose_cooptation(user, motivation)` → crée proposition + **vote favorable auto du proposeur** | `fn_request_propose_decision(request, decision, disclose, …)` |
| `fn_network_admin_vote_cooptation(proposal, vote, disclose, rationale)` → enregistre, **détecte l'unanimité**, déclenche les conséquences | `fn_request_vote(request, vote, disclose, rationale)` |
| `fn_cron_cooptation_send_reminders()` (D.7, J+14/J+25, event unique fenêtre 24 h) | `fn_cron_request_eval_digest()` (digest ONBO-Q10) |

> ⚠️ **Avant de coder le Lot 1**, relire `pg_get_functiondef` de `fn_network_admin_vote_cooptation` **sans troncation** : c'est le gabarit exact de la détection d'unanimité (comptage des admins actifs, gestion abstain, transition d'état, garde « déjà tranché »). On le réplique pour `fn_request_vote`.

---

## 2. État réel du schéma (vérifié le 18/06, baseline `20260510000000`)

**`public.library_requests`** — existe. Manquent (à ajouter au Lot 1) :
- statuts : la CHECK actuelle = `('pendente','em_analise','aprovada','recusada','arquivada')`. **À étendre** avec `'proposta_aprovacao'`, `'proposta_recusa'`, `'aguardando_info'`, `'cancelada'` (et conserver `arquivada`). *(`expirada` : cf. arbitrage §6.)*
- colonnes : `proposed_by_admin_id uuid`, `proposed_at timestamptz`, `proposed_decision text CHECK in ('aprovacao','recusa')`, `proposed_disclose_identity boolean` (**pas de DEFAULT**), `refusal_category text CHECK in (…7 valeurs §2.7…)`, `refusal_reason text`.
- **0 demande en prod** (`total_requests=0`) → aucun backfill, aucune migration de données. Confort maximal.

**Tables à CRÉER** (Lot 1 : votes + comments ; Lot 2 : messages + invitations) — schémas en §3/§4.

**Déjà en place et réutilisé** : `network_administrators` (statut actif), `public.fn_caller_is_network_admin()`, `api.fn_approve_library_request` (provisionne — accept), trigger notif `tg_library_requests_notify` + `fn_enqueue_library_request_notification`, EF `notify-library-request`.

**Manque pour le refus** : pas de `fn_refuse_library_request`. Le refus simple (mode dégradé) se fait aujourd'hui par UPDATE direct (`recusada`) **sans** poser `solicitante_state='solicitante_recusada'`. ⚠️ **Même classe de trou que celui corrigé pour l'approbation** → le Lot 1 crée un `fn_request_finalize_refusal` qui pose `recusada` + `solicitante_state='solicitante_recusada'` + `refusal_category/reason`, et RedePage l'appellera (cf. Lot 3).

---

## 3. LOT 1 — Modèle d'évaluation + vote à l'unanimité (1 migration + 1 suite SQL)

### 3.1 DDL

```sql
-- a) library_requests : statuts + colonnes de proposition/refus
ALTER TABLE public.library_requests DROP CONSTRAINT library_requests_request_status_check;
ALTER TABLE public.library_requests ADD CONSTRAINT library_requests_request_status_check
  CHECK (request_status IN ('pendente','em_analise','proposta_aprovacao','proposta_recusa',
                            'aguardando_info','aprovada','recusada','cancelada','arquivada'));
ALTER TABLE public.library_requests
  ADD COLUMN proposed_by_admin_id uuid REFERENCES public.profiles(id),
  ADD COLUMN proposed_at timestamptz,
  ADD COLUMN proposed_decision text CHECK (proposed_decision IN ('aprovacao','recusa')),
  ADD COLUMN proposed_disclose_identity boolean,
  ADD COLUMN refusal_category text CHECK (refusal_category IN
    ('info_insuffisante','non_verifiable','desalignement_politique','doublon',
     'prematuro','repeticao_sem_evolucao','autre')),
  ADD COLUMN refusal_reason text;

-- b) votes (calqué sur network_administrator_cooptation_votes)
CREATE TABLE public.library_request_votes (
  request_id uuid NOT NULL REFERENCES public.library_requests(id) ON DELETE CASCADE,
  voter_admin_id uuid NOT NULL REFERENCES public.network_administrators(user_id),
  vote text NOT NULL CHECK (vote IN ('favorable','opposed','abstain')),
  voted_at timestamptz NOT NULL DEFAULT now(),
  rationale text,
  disclose_identity boolean NOT NULL,
  PRIMARY KEY (request_id, voter_admin_id),
  CONSTRAINT rationale_required_for_opposed
    CHECK (vote <> 'opposed' OR (rationale IS NOT NULL AND length(btrim(rationale)) >= 20))
);

-- c) commentaires internes admins
CREATE TABLE public.library_request_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.library_requests(id) ON DELETE CASCADE,
  author_admin_id uuid NOT NULL REFERENCES public.profiles(id),
  content text NOT NULL CHECK (length(btrim(content)) > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);
```

**RLS (doctrine — les 2 tables) :** `ENABLE ROW LEVEL SECURITY` + policy SELECT `TO authenticated USING (fn_caller_is_network_admin())`. **Aucune** policy d'écriture (écriture only via RPC SECDEF owner postgres). `REVOKE ALL … FROM PUBLIC, anon` + `GRANT SELECT … TO authenticated`. *(library_requests a déjà ses policies — cf. spec §3.2 ; vérifier qu'elles couvrent bien la lecture solicitante + admin avant de livrer.)*

### 3.2 RPC (schéma `api`, SECURITY DEFINER, search_path `'public','auth','pg_temp'`, REVOKE PUBLIC/anon/service_role + GRANT authenticated)

1. **`fn_request_propose_decision(p_request_id, p_decision text, p_disclose_identity boolean, p_refusal_category text DEFAULT NULL, p_refusal_reason text DEFAULT NULL, p_rationale text DEFAULT NULL)`**
   - Garde `fn_caller_is_network_admin`. `p_disclose_identity` **obligatoire** (NULL → 23514).
   - Demande doit être en `pendente`/`em_analise`/`aguardando_info` (pas déjà tranchée/proposée).
   - `decision='recusa'` → `refusal_category` obligatoire (∈ liste).
   - Pose `request_status='proposta_aprovacao'|'proposta_recusa'`, `proposed_by_admin_id=auth.uid()`, `proposed_at=now()`, `proposed_decision`, `proposed_disclose_identity`, (refus : `refusal_category/reason`).
   - **Insère le vote favorable auto du proposeur** dans `library_request_votes` (comme la cooptation).
   - Appelle `fn_request_check_unanimity(p_request_id)` (cf. §3.3) → **mode dégradé** : si < 3 admins actifs, l'unanimité est trivialement atteinte → confirmation immédiate (= comportement actuel préservé).

2. **`fn_request_vote(p_request_id, p_vote text, p_disclose_identity boolean, p_rationale text DEFAULT NULL)`**
   - Garde admin. Demande en `proposta_*`. `disclose_identity` obligatoire ; `opposed` → rationale ≥ 20.
   - Upsert dans `library_request_votes`. Puis `fn_request_check_unanimity`.

3. **`fn_request_comment(p_request_id, p_content)`** — garde admin ; insert commentaire.

4. **`fn_request_finalize_refusal`** *(interne, appelée par check_unanimity ; pas exposée)* : pose `recusada` + `solicitante_state='solicitante_recusada'` (⚠️ le trou symétrique de l'approbation) + déclenche la notif refus.

### 3.3 Trigger / fonction d'unanimité

`private.fn_request_check_unanimity(p_request_id)` (SECDEF, **réplique `fn_network_admin_vote_cooptation`**) :
- compte les admins actifs `N`, les votes `favorable`/`opposed`.
- **un seul `opposed` → veto** : la proposition tombe (retour à `em_analise` ; la rationale opposed reste affichée même identité masquée, cf. §2.7/doctrine R6).
- **tous les actifs ont voté favorable** (`abstain` toléré ? cf. cooptation — s'aligner sur sa règle exacte) → si `proposed_decision='aprovacao'` : `PERFORM api.fn_approve_library_request(p_request_id)` (provisionne) ; sinon `fn_request_finalize_refusal`.
- **Mode dégradé** (`N < 3`) : un seul vote favorable (celui du proposeur) suffit → confirmation immédiate.

> Le **trigger** `trg_check_request_unanimity AFTER INSERT ON library_request_votes` (spec §3.3) peut être remplacé par un **appel explicite** à `fn_request_check_unanimity` en fin de chaque RPC vote/propose (plus lisible, transactionnel, testable). **Choisir l'appel explicite** (évite les surprises de réentrance avec `fn_approve` qui écrit `library_requests`). Documenter ce choix.

### 3.4 Test SQL — `tests/sql/onbo_111_lot1_eval_tests.sql` (+ allowlist `ci-suites.txt`)

Fixture autonome (3 admins via `network_administrators` + `auth.users`/`profiles`, 1 demande). Cas : propose accept (mode dégradé 1 admin → auto-`aprovada` + provisioning) ; propose refus (catégorie obligatoire) ; 3 admins → unanimité requise (2 favorables ≠ confirmé, 3ᵉ favorable → confirmé) ; 1 `opposed` (rationale <20 → rejet ; veto → retombe) ; non-admin/anon rejetés ; `disclose_identity` NULL rejeté. Bilan `RAISE … OBNO-111-L1 OK : N/N`.

---

## 4. LOT 2 — Échange humain : messages + « proposer un échange » (1 migration + Edge Function + mail-strings ×10)

### 4.1 DDL

```sql
CREATE TABLE public.library_request_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.library_requests(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES public.profiles(id),
  direction text NOT NULL CHECK (direction IN ('admin_to_solicitante','solicitante_to_admin')),
  content text NOT NULL CHECK (length(btrim(content)) > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz
);
CREATE TABLE public.library_request_invitations (  -- « proposer un échange »
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.library_requests(id) ON DELETE CASCADE,
  initiated_by uuid NOT NULL REFERENCES public.profiles(id),
  initiator_side text NOT NULL CHECK (initiator_side IN ('admin','solicitante')),
  subject text NOT NULL,
  proposed_at_text text,            -- date/horaire proposé (texte libre, fuseau humain)
  status text NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed','accepted','declined','completed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz
);
```
**RLS** : messages/invitations visibles par l'admin réseau **et** par la solicitante propriétaire de la demande (`submitted_by_user_id = auth.uid()`). Écriture via RPC.

### 4.2 RPC
- Admin : `fn_request_send_message` (direction admin→solicitante ; passe la demande en `aguardando_info` si complément), `fn_request_propose_exchange(subject, proposed_at_text)`, `fn_request_exchange_respond(invitation, accept/decline)`, `fn_request_exchange_complete`.
- Solicitante (garde `submitted_by_user_id = auth.uid()`) : `fn_request_solicitante_message`, `fn_request_solicitante_request_exchange` (le symétrique §4.5/§5.7).

### 4.3 Mail (events + EF + strings)
- **Events** (via `fn_enqueue_library_request_notification`, nouveaux `event_type`/`event_key`) : `onboarding.echange_propose_admin` (admin→solicitante), `onboarding.echange_demande_solicitante` (solicitante→admins actifs), `onboarding.echange_reponse`, `library_request_more_info` (déjà géré par le trigger pour `aguardando_info` — vérifier la couture).
- **EF** : étendre `notify-library-request` (ou `notify-event`) pour rendre ces events. Respecter le contrat `actionBox` de `renderEmail` (cf. REGISTRE doctrines internalisées). ⚠️ MCP ne peut pas déployer `notify-event` (bundle volumineux) → **déploiement CLI = la CI** (`supabase functions deploy`). Ne pas tenter via MCP.
- **mail-strings ×10 locales** (charte inclusive ; `it` jamais `camerata`). Tester avec `mail-i18n-test`.

> Lot 2 = le lot qui touche EF + mail → le plus lourd à vérifier. Prévoir un passage `advisor` après DDL et un test `mail-i18n-test`.

---

## 5. LOT 3 — Interfaces + digest (frontend + cron)

### 5.1 RedePage (`/rede`, admin réseau) — vue détaillée enrichie (spec §5.3/§5.4)
- Historique chronologique (proposition, votes, commentaires, messages, invitations).
- Boutons : **Proposer l'acceptation** / **Proposer le refus** (catégorie obligatoire + `disclose_identity` choisi explicitement — **case à cocher sans valeur par défaut**), **Voter** (favorable/opposed/abstain + rationale si opposed), **Commenter**, **Proposer un échange**, **Envoyer un message**.
- Filtres liste par statut/date/catégorie de refus (spec §5.2).
- Appelle tous les RPC `api.fn_request_*` via `apiRpc`. *(Le bouton « Approuver » direct du mode dégradé devient « Proposer l'acceptation » ; en < 3 admins il auto-confirme → même effet qu'aujourd'hui.)*

### 5.2 `/conta` côté solicitante (spec §4.2–4.4)
- États `solicitante_inicial` / `solicitante_pendente` / `solicitante_recusada` : onglet unique « Ma demande », bandeaux, **section Échanges** (lire/écrire messages, répondre à une invitation, demander un échange), **motif de refus** (catégorie + motif + identité si `disclose_identity`).

### 5.3 Digest proactif (ONBO-Q10) — cron
- `fn_cron_request_eval_digest()` **calqué sur `fn_cron_cooptation_send_reminders`** : rappel aux admins n'ayant pas voté sur les `proposta_*` ouvertes + demandes `pendente` en attente. Event unique fenêtre 24 h.
- Job pg_cron créé **INACTIF**, activé après EF+secret, via `cron.alter_job` (⚠️ **jamais** `UPDATE cron.job` — perm denied au db push ; cf. mémoire `pg-cron-alter-job-not-update`).

### 5.4 i18n
- Toutes les chaînes via `t({id})` ; clés `rede.eval.*`, `conta.demande.*`, mail-strings — **×10 locales, parité gardée par la CI**. Méthode d'insertion **minimale** (script node, insertion-texte à l'ancre, jamais de re-`sort()` global qui réordonne tout le fichier — cf. leçon ONBO-Q13).

---

## 6. Points d'arbitrage restants (à trancher avec Carlos / coordination avant le lot concerné)

1. **Deadline `coordenador_em_constituicao` (60 j)** — spec §3.3/§10 : que se passe-t-il à l'expiration ? (relance ? libération ? transfert auto ? lié à ONBO-Q13). **Non bloquant pour #111** ; à arbitrer.
2. **Statut `expirada`** — faut-il un statut distinct pour les demandes périmées, ou réutiliser `arquivada` ? (cohérence avec le digest).
3. **`abstain` et unanimité** — s'aligner **exactement** sur la règle de la cooptation (un·e abstentionniste bloque-t-il l'unanimité ?). À lire dans `fn_network_admin_vote_cooptation` avant de coder.
4. **Quorum = 3** — confirmer que le seuil mode-dégradé/collaboratif est bien 3 (spec admin réseau). 
5. **Interaction ONBO-Q13** — un transfert de mandat opère **après** acceptation (en constitution) ; #111 opère **avant** (évaluation). Pas de conflit, mais le documenter.
6. **Volet 10 (`regimento`)** — ⚠️ **déjà câblé** (regimentoPdf.js + `fn_activate_approved_library_request`). L'ancien label « volet 10 à finir » des specs/REGISTRE/docx audit est **périmé** → à corriger lors des MàJ doc (ne PAS le re-coder).

---

## 7. Séquençage & doctrine transverse

- **Ordre** : Lot 1 (fondations + vote) → pipeline vert → Lot 2 (échange + mail/EF) → vert → Lot 3 (UI + digest). **Un push à la fois**, run précédent vert avant le suivant (règle d'or ; + session cartographie active → `git fetch` avant push, staging explicite, jamais `git add -A`).
- **Chaque migration** : horodatage UTC réel > max du dossier ; SECDEF + search_path ; REVOKE PUBLIC/anon/service_role + GRANT ciblé ; RLS+policy sur toute table `public.*` ; `DROP … IF EXISTS` sans CASCADE ; `NOTIFY pgrst, 'reload schema'` en fin ; **test SQL fixturé** dans `tests/sql/` + allowlist, **validé en local sur l'image CI** (`docker run public.ecr.aws/supabase/postgres:17.6.1.084` + `scripts/ci/run-sql-suites.sh`) avant push ; `advisor` après DDL.
- **Doctrine politique** (spec) : `disclose_identity` **sans DEFAULT** (choix conscient) ; rationale ≥ 20 si opposé ; anti-méga-machine (canal humain visible) ; mode dégradé = comportement actuel préservé ; RLS via `fn_caller_is_network_admin()`.
- **Front** : RPC `api` via `apiRpc` (jamais `supabase.rpc` pour le schéma api) ; build + lint + test i18n avant commit.

## 8. Conséquences backlog / doc (rule #12) — à faire en clôturant #111

- REGISTRE : marquer #111 lot par lot ; corriger le statut « volet 10 à finir » (→ ✅ câblé) ; consigner le fix « refus provisionnant » (symétrique de l'approbation, ONBO-Q13).
- spec-onboarding v2.0 : annoter §5 « implémenté (lots 1-3, commits …) ».
- docx audit (`~/Downloads/AnarBib_Audit_360_2026-06-18.docx`) : passer #111 de 🔴 à « en cours / livré » selon l'avancement, retirer la mention « volet 10 ».
- `docs/backlogs/ETAT-AVANCEMENT-multisessions.md` : ligne #111.
