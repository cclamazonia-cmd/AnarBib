# CADRAGE ONBO-Q2 — Câblage des volets de constitution via biblio pré-active

- **Date** : 2026-06-13
- **Chantier** : Onboarding / Oficina de constituição (suite de ONBO-A1→A4)
- **Auteur** : Claude (Opus 4.8), session « MLEG / #LIB-SIGNUP-UI » → ONBO-Q2
- **Statut** : plan validé (voie A + provisioning à l'approbation). Lot 1+2 en cours.
- **Réfs** : `docs/specs/spec-onboarding-biblioteca-v2.0.md` §6.3-6.4 ; `src/pages/atelier/AtelierConstituicaoPage.jsx` ; commits ONBO-A1 `f327cb27`, A2-A4 `2b31574e`.

## 1. Problème

L'atelier `/atelier` (ONBO-A1→A4) est livré comme **mécanique de discussion collective** :
hub-and-spoke, canal humain par volet, profil (volet 0), regimento (volet 10), PDF,
progression — le tout keyé par `request_id` (`library_constitution_progress`). Les RPC
`fn_constitution_*` ne font que **marquer « discuté en collectif »** + stocker profil/PDF.

**Aucun row `libraries` n'existe pendant la constitution** (création seulement à
l'activation par admin réseau via `fn_activate_approved_library_request`). Donc les champs
des volets 1-9 sont des **leurres** : rien à éditer. C'est le manque ONBO-Q2 (« champs des
panneaux → vrais composants »), noté en tête de `AtelierConstituicaoPage.jsx`.

La spec §6.4 prescrit une biblio **« pré-active »** pendant la constitution, qui **bascule
en active** au volet 10 (regimento uploadé), avec inscription du profil dans `libraries.*`.
Cet état pré-active n'est pas implémenté.

## 2. Décision d'architecture — Voie A : biblio pré-active

Créer le row `libraries` en **pré-active** (`is_active=false`) dès le début de la
constitution → les volets éditent cette biblio via **les composants existants de
`BibliotecaPage`** (TeamPanel, PolicySetManager, LibraryVisualAssetsSection…) scopés au
`library_id` ; l'activation = **bascule** `is_active=true` au volet 10. Source unique de
vérité, zéro duplication. (Voie B « stockage côté demande + transfert » écartée :
duplication massive, divergence spec.)

### Faisabilité vérifiée (2026-06-13)

- **Anti-fuite** : `fn_library_visible_to_caller` exige `is_active=true` (catalogue) et la
  policy `libraries_public_signup_read` aussi → une biblio `is_active=false` est invisible
  catalogue + signup **automatiquement**. Le verrou principal est couvert par `is_active`.
- **Édition staff** : `user_can_act_as_staff_on_library` = vrai si membership **active
  `coordenador`** sur la biblio. Il suffit de créer cette membership dès le provisioning, et
  `libraries_staff_update` autorise alors tous les éditeurs de volets.

## 3. Questions tranchées

1. **Déclencheur du provisioning** : à l'**approbation admin** de la demande (la biblio à
   constituer existe dès le go). ✅
2. **Réconciliation avec le correctif MLEG** sur `fn_activate_approved_library_request` :
   scinder proprement (provision vs flip) en réintégrant la logique A3 `accepts_public_signup`. ✅
3. **Périmètre premier code** : **Lot 1 + Lot 2** (fondation + volet pilote). ✅
4. **Persister ce cadrage** : oui (ce document). ✅

## 4. Lots

### Lot 1 — Fondation backend (lifecycle pré-active) · migration(s)
1. `fn_provision_preactive_library(p_request_id)` (nouvelle) : extrait de
   `fn_activate_approved_library_request` la création (libraries `is_active=false` + axes
   volet 0, `library_commons`, `library_email_identity`, `library_service_state`,
   **membership `coordenador` active**) ; pose `accepts_public_signup` selon A3 ; renseigne
   `library_requests.approved_library_ref` + `library_constitution_progress.library_id`.
2. Activation = **flip** : refondre `fn_activate…`/`fn_constitution_complete` pour basculer
   `is_active=true` + `visibility_level`/réseau selon volets 8/0 + sortir de
   `coordenador_em_constituicao` — au lieu d'INSERT, au volet 10.
3. `library_constitution_progress.library_id` exposé dans `my_constitution_progress_v1`.
4. **Audit RLS anti-fuite** : confirmer que `is_active=false` masque partout
   (federation/círculos, `library_partnerships`, OAI `fn_oai_harvestable_*`,
   `v_libraries_for_signup`, annuaires) ; filtrer là où il manque.
5. Garde-fous (pas d'emprunt/inscription/PEB sur pré-active) + cleanup si demande rejetée.

### Lot 2 — Volet pilote (volet 1 « identité ») bout-à-bout · front
Câbler le slide-over du volet 1 aux composants réels (`LocaleSelector`,
`LibraryVisualAssetsSection`, `LibraryContactProfileSection`) scopés au `library_id`
pré-actif, `canEdit` selon staff ; garder canal humain + action « discuté em coletivo » ;
valider provisioning → édition → persistance → activation test.

### Lot 3 (ultérieur) — généralisation volets 2-9
Mapping (cf. `VOLETS` + spec §6.3) : v2 horaires→service_state · v3 pessoas→TeamPanel ·
v4 catalogação→política · v5 circulação→PolicySetManager/RegimeStateBox · v6 adhésion→règles
membership · v7 emails→comms · v8 visibilité→LibraryPartnershipsSection/DocumentGovernance ·
v9 dados→RetentionPolicySection. Respect des conditionnels `applies(axes)`.

### Lot 4 (ultérieur) — activation finale & transitions (volet 10 → live).

## 5. Risques & transverse

- **Intersection correctif MLEG** : `fn_activate_approved_library_request` fraîchement
  refondu (migration `20260612222920`) → réintégrer A3 dans le provisioning, garder l'historique propre.
- **Audit RLS exhaustif** = plus gros risque de fuite (biblio pré-active visible quelque part).
- **Multi-session** : clone partagé avec la session OAI (RedePage/federation/ILL). i18n des
  volets → même protocole que #LIB-SIGNUP-UI (gel + staging chirurgical).
- **Rétro-compat** : demandes déjà approuvées sans biblio (aucune réelle en prod hors test).
- **Découpage** : Lot 1 (backend, vérifiable SQL) puis Lot 2 (volet pilote) ; chaque lot
  commit/push/CI-vert séparé, staging chirurgical vs OAI.
