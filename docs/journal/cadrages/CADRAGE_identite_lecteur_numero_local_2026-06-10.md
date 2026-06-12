---
Genre : trace (cadrage de chantier) — **v2 (réécriture)**
Statut : ✅ arbitré (REGISTRE §27 `CARD-LOCAL`, 11/06) — Lots 0→5 construits (Lot 0
déployé 11/06 ; Lots 1→5 le 12/06, en attente de push). Le §9 ci-dessous est conservé
comme TRACE de l'arbitrage : sa source de vérité est désormais le **REGISTRE §27**.
Date : 2026-06-10 (v1) · réécrit 2026-06-10 (v2)
Session : Catalogação work completion (v1) · réécriture v2 avec Xavier
Préséance : ce document est une TRACE non-normative. Les décisions, une fois prises,
sont inscrites au REGISTRE_decisions.md (qui fait foi). Ne pas recopier une décision
ici — lier/citer plutôt (ID du REGISTRE).
Références : MULTI-E.2 · MULTI-F.1 · MULTI-β.1 (REGISTRE §20) ; VALID-AMD · VALID-C1..C4
(REGISTRE §9) ; CARD-FLAG · CARD-A.2 (REGISTRE §23) ; DOC-I18N-1 · DOC-ADDR-1 · DOC-NOTIF-1
(REGISTRE §0) ; spec-multi-appartenance-lecteur v0.3 ; spec-validation-physique v1.1.
Dépendances : panne Woodpecker (déploiement N4) ; charte langage inclusif (i18n).
---

# CADRAGE v2 — Identité de lecteur·rice locale : modèle biblio, recherche, attribution, roster, canaux

> **Pourquoi une v2.** La v1 (rédigée le matin du 10/06) sous-créditait le socle déjà
> livré et parlait de « numéro local ». Deux choses ont changé : (1) **vérification
> du code** — tout le socle §20 MULTI (P1→P5) est **en prod** ; (2) **recadrage Xavier** —
> on ne parle plus de « numéro » mais d'**identité locale de lecteur·rice**, parce
> qu'une biblio a pu décider historiquement que l'identité de ses lecteur·rices,
> c'est un **numéro**, un **nom**, ou un autre schéma maison. Le champ DB
> `local_reader_number` reste, mais il **porte une identité**, pas forcément un nombre.

---

## 1. Problème (cas réels rapportés)

AnarBib attribue à la création du compte un **UUID / `public_id`** stable, transverse,
connu de la lectrice et de sa **première** bibliothèque. Sur le terrain, deux frictions :

- **Réconciliation.** La lectrice arrive dans une **seconde** biblio pour la validation
  physique, **oublie de donner son UUID** ; le·la bibliothécaire lui attribue une
  **identité au format de SA biblio** (registre interne, parfois ancien). Plus tard,
  ce·tte bibliothécaire cherche le compte avec **cette identité** dans le painel… **ça
  ne marche pas** : la recherche n'accepte pas l'identité locale.
- **Deux populations.** Chaque biblio coexiste avec des **ancien·nes lecteur·rices**
  (registre papier, format « à l'ancienne ») et des arrivées AnarBib. Identités
  hétérogènes, non conformes aux standards locaux encore en vigueur, et **personne ne
  s'y retrouve** — ni le staff, ni la lectrice qui s'inscrit a posteriori pour suivre
  son historique.

**Besoin** : que chaque bibliothèque puisse **définir son modèle d'identité**,
**attribuer, chercher, relier et éditer** par **son** identité locale, **exporter**
l'état de ses comptes, et que **la bonne info parvienne à la bonne personne au bon
moment par le bon canal** — tout en gardant l'UUID comme identifiant transverse.

## 2. Recadrage terminologique (Xavier, 10/06)

- On dit **identité locale de lecteur·rice**, pas « numéro local ». Le champ existant
  `local_reader_number` (texte libre) peut porter un **numéro**, un **nom**, un code
  maison, etc. L'UI et les libellés i18n doivent rester **neutres** (« identifiant /
  identité dans cette biblio »), pas « numéro ».
- **Le lecteur·rice ne s'attribue JAMAIS son identité locale.** C'est un **acte du staff**
  de la biblio (en cohérence avec MULTI-E.2 « saisie staff à la validation »). Tout ce
  que le wizard / les e-mails font, c'est **informer** — jamais laisser saisir.

## 3. Principe directeur

- **UUID (`public_id`)** = identité **transverse, stable, inter-biblios** (carte-lecteur).
  Jamais réécrite, pont entre biblios.
- **Identité locale** = identité **par bibliothèque, au format propre de la biblio**.
  Plusieurs biblios → plusieurs identités pour la même personne, c'est **attendu**.
- Les deux **coexistent** ; chaque biblio retrouve « sa » personne par « son » identité
  **ou** par l'UUID. Tout ce qui touche à l'identité locale est **toujours dans le
  contexte d'une biblio** (RPC `p_library_id` explicite — cf. MULTI-Z15).

## 4. État réel vérifié (le socle est DÉJÀ là — §20 MULTI P1→P5, livré 08–10/06)

> Correction majeure de la v1 (« on n'ajoute pas de modèle d'identité ; on ouvre les
> portes ») : **le modèle d'appartenance est posé et déployé**. Ce chantier ouvre des
> portes **et** ajoute un petit **modèle côté biblio** (voir N5).

**✅ Déjà en prod (vérifié dans le code) :**

| Brique | Preuve |
|---|---|
| `user_library_memberships.local_reader_number` (texte libre) + index unique `ux_ulm_local_reader_number (library_id, local_reader_number)` (NULL multiples tolérés) | `20260608145936` (MULTI-E.2) |
| Validation physique **par appartenance** : `physically_validated_at/by_user_id`, `physical_validation_note` ; journal `membership_validation_log` (action validated/revalidated/invalidated + `local_reader_number` attribué) | `20260608145936` (VALID-AMD) |
| RPC `api.validate_membership(membership_id, local_reader_number, note)` — **assigne l'identité à la validation** (staff) | `20260608154320` |
| RPC `api.request_membership(p_library_id)` — auto-inscription → `pending_validation` (garde β.1) | `20260608154320` |
| **Gate de circulation** `fn_membership_can_engage_circulation` + triggers BEFORE INSERT sur `emprestimos_v2` et `consultas_locais_v2` (5 conditions MULTI-F.1) | `20260608153720` + `20260610035651` (cond. 5 plafonds) |
| `api.fn_my_memberships_status()` expose à la lectrice **statut + identité locale par biblio** (`/conta`) | `20260608151435` |
| E-mail **`validation_confirmed`** (→ lectrice, 10 langues) incluant `readerNumberLabel` + `local_reader_number` s'il existe | `membership.ts:160` + `20260609225414` |
| E-mail **`membership_validation_requested`** (→ biblio/staff) à la demande d'inscription | `20260610014812` |
| E-mails de **création de compte** (`register`) : welcome lectrice (avec `public_id` + mot de passe provisoire), interne biblio (avec `public_id`), interne admin | `register/index.ts` |
| Config biblio : `reader_cards_enabled` (CARD-FLAG), `accepts_public_signup`, `membership_enabled` | `20260528120000`, `20260512090000` |

**❌ Manque / à confirmer (le cœur du chantier) :**

| Manque | Note |
|---|---|
| **Recherche painel par identité locale** | À confirmer : la def de `fn_painel_find_profile_by_lookup` n'est **pas dans les migrations** (objet hors-migration, comme la MV catalogue). Un `fn_painel_find_profile_by_email` existe. → **lire la source réelle avant de coder.** |
| **UI d'attribution/édition** de l'identité locale hors validation (dans la gestion lecteur·rice) | `TabValidacoes` la pose **à la validation** ; rien pour éditer une identité « à l'ancienne » sur un compte déjà actif. |
| **Onglet Rapports + roster** « état des comptes lecteurs » (legacy + AnarBib) | **Aucun onglet Rapports** aujourd'hui (à confirmer). Plomberie CSV réutilisable (`DataExportButton`, export §12). |
| **Modèle d'identité côté biblio** (schéma/pattern, dernier identifiant attribué) | N'existe pas. C'est l'ajout demandé (N5). |
| **Mode de validation par biblio** (présentielle / à distance / aucune) | N'existe pas comme config exploitable. La spec-validation-physique évoque `network_access_mode {open, manual_validation}` — **à vérifier dans le code**. Nécessaire pour le bon message « identité envoyée par e-mail SI pas de validation physique ». |
| **Marqueur legacy vs AnarBib** sur l'appartenance | Aucun. Nécessaire pour distinguer les deux populations dans le roster. |
| `preferred_login_identifier` **affiché** dans l'e-mail welcome | Choisi à l'inscription mais **jamais rappelé** à la lectrice. |

## 5. Sous-lots

### N1 — Recherche par identité locale *(quick win, le plus urgent)*
Étendre la recherche painel pour accepter **aussi** l'identité locale, **scopée à la
biblio courante** (les identités ne sont pas uniques entre biblios → désambiguïsation
par `library_id` du contexte). **Préalable obligatoire** : lire la def réelle de
`fn_painel_find_profile_by_lookup` (hors migrations). Frontend : le champ existant
accepte UUID / e-mail / **identité locale**, hint mis à jour (neutre, tutoiement
DOC-ADDR-1).

### N2 — Attribution / édition de l'identité locale (UI staff)
Dans la gestion lecteur·rice (`TabLeitor`), un champ pour **créer/éditer l'identité au
format de la biblio**, pour **tout·e** lecteur·rice (ancien·ne « papier » comme arrivée
AnarBib), **indépendamment de la validation**. RPC d'écriture gardée staff (`set_local_
reader_identity(p_user_id, p_library_id, p_value)`), unicité par biblio (message clair
si collision, **sans révéler** le compte existant). L'attribution **à la validation**
reste via `validate_membership` (déjà là) — les deux chemins écrivent le même champ.

### N3 — Roster « état des comptes lecteurs » dans l'onglet **Rapports** *(outil de transition)*
**Crucial** (rappel Xavier) : à la mise en place du nouveau système, coordinateur·rices
et bibliothécaires ont besoin d'une **édition à jour de l'état des comptes**, qui
**distingue legacy et AnarBib**, pour reprendre l'ancien **en douceur**. Création d'un
**onglet Rapports** (n'existe pas) avec un export : **NOM, Prénom, inscrit·e depuis,
e-mail, UUID, identité locale, statut d'appartenance** + en option **emprunts en cours,
réservations ouvertes, consultations demandées, cotisation**. Marqueur **legacy /
AnarBib** par ligne. Export CSV (réutilise `DataExportButton` / §12). Gardé
staff/coordenador, scopé à la biblio du contexte (RLS).

### N4 — Notification e-mail de réconciliation (bon canal, bon moment)
À l'**attribution de l'identité** (validation **ou** édition N2), informer la lectrice
(et la biblio) du lien **UUID ↔ identité locale**. Le socle existe (`validation_confirmed`
porte déjà l'identité) ; restent : (a) **copie à la biblio** ; (b) un canal pour
l'attribution **hors validation** (N2) ; (c) éviter le **double envoi** quand validation
et attribution coïncident. Passe par `notify-event` (⚠️ déploiement tributaire de
Woodpecker).

### N5 — Modèle d'identité **côté bibliothèque** *(nouveau — demande Xavier)*
Côté identité de la biblio, lui permettre de :
1. **Définir son modèle principal d'identité lecteur·rice** (numéro libre / numéro
   séquencé / nom / autre) — **en définir un si absent** ;
2. voir, à l'ouverture de son espace AnarBib, **la dernière identité attribuée** (hint,
   sur le modèle du « dernier tombo » de la catalogação) ;
3. déclarer son **mode de validation** (présentielle / à distance / aucune) et son
   **usage de carte** (`reader_cards_enabled` existe) — ces deux infos pilotent le
   **message** envoyé à la lectrice (voir §6).

> ⚠️ **Garde-fou** : le « modèle » est un **guide non bloquant** (pattern + cache du
> dernier identifiant), **jamais un validateur dur** — sinon il rejetterait les
> identités « à l'ancienne » hétérogènes encore en vigueur.

## 6. La boussole — bonne info · bonne personne · bon moment · bonne manière · bon canal

C'est le cœur du recadrage. Matrice cible (chaque ligne = un message) :

| Info | À qui | Quand | Canal | Statut |
|---|---|---|---|---|
| **UUID `public_id`** | lectrice + biblio | à la **création** | e-mail welcome (✅) + interne biblio (✅) | ✅ existe |
| **Identifiant de login** (`preferred_login_identifier`) | lectrice | à la **création** | e-mail welcome | ❌ manque (gap) |
| **« Comment marche TA biblio »** : avec/sans carte ; identité envoyée plus tard par e-mail (si **pas** de validation physique) **ou** à ton **premier passage** | lectrice | à la **création** (wizard + welcome) | wizard + e-mail welcome | ❌ manque (dépend N5 : mode validation + carte) |
| **« Tu es en attente »** : pas encore de résa/consultation/emprunt tant que non validé·e ; voici comment être validé·e | lectrice | à la **création** + tant que `pending_validation` | e-mail welcome + bandeau `/conta` (statut déjà exposé) | ⚠️ partiel (bandeau ok ; message création à écrire) |
| **Identité locale attribuée** (lien UUID ↔ identité) | lectrice **+ biblio** | à la **validation / attribution** (PAS à la création : elle n'existe pas encore) | `validation_confirmed` (→ lectrice ✅) + copie biblio (❌) + canal N2 (❌) | ⚠️ partiel |

**Tension résolue (Xavier).** « Informer à la création » **≠** « envoyer l'identité à la
création » : à la création l'identité **n'existe pas encore** (acte staff ultérieur). À
la création, on **explique le mécanisme et le calendrier** ; à la validation/attribution,
on **communique l'identité**. Le « semi-automatisé » = le wizard/les e-mails **pré-câblent
le discours** (à partir du modèle N5 de la biblio), mais l'attribution reste **manuelle
et staff**.

## 7. Circulation : ce qui bloque, ce qui ne bloque pas (clarification MULTI-F.1)

- L'**état intermédiaire bloquant** « pas encore de résa/consultation/emprunt » **existe
  déjà** : c'est le statut **`pending_validation`** + le gate `fn_membership_can_engage_
  circulation` (code `no_active_membership`). Sortie de cet état = **validation staff**
  (présentielle, ou à distance selon N5).
- ⚠️ **Décision à acter** : l'identité locale **ne doit PAS** devenir une 6ᵉ condition de
  circulation. Aujourd'hui le gate s'appuie sur **l'appartenance validée** (`status =
  'active'`), **pas** sur la présence d'une identité. Coupler circulation ⇄ présence
  d'identité **bloquerait** les biblios qui n'utilisent que l'UUID (ou le nom). **Reco :
  garder le gate sur la validation ; l'identité reste attribuée-à-la-validation mais
  NON bloquante.** L'« état intermédiaire » que décrit Xavier = `pending_validation`,
  rien à ajouter.

## 8. Cas limites (chasse — à trancher avant de coder)

1. **Identité = nom.** Si une biblio identifie par le **nom**, deux choses :
   (a) l'index unique `(library_id, local_reader_number)` **interdit les homonymes**
   (deux « Jean Dupont » → collision) → prévoir une désambiguïsation, **ou** considérer
   que « identité = nom » signifie *« cette biblio n'attribue pas d'identité séparée et
   cherche par le nom du profil »* (alors `local_reader_number` reste vide et la
   **recherche par nom** doit marcher dans le painel). À clarifier dans N5 (modèle =
   `{numéro | nom | aucun}`).
2. **Multi-biblios.** Une personne a une identité **par** biblio ; l'e-mail de création
   (contexte d'**une** biblio) ne peut pas énumérer les futures identités. Chaque
   identité se communique à **la** validation de **sa** biblio. La 2ᵉ inscription part en
   `pending_validation` (garde β.1).
3. **Legacy sans compte AnarBib.** L'identité locale vit sur une **appartenance**, qui
   exige un compte. Un·e lecteur·rice **100 % papier sans compte** ne peut pas en
   porter → le roster ne le·la liste pas. C'est l'**import de masse des registres**
   (hors-scope §10), à ne pas confondre avec N2 (qui couvre les legacy **déjà
   titulaires d'un compte**).
4. **Marqueur legacy vs AnarBib.** Aucun champ ne distingue les deux populations.
   Options : (a) `created_at` de l'appartenance **antérieur** à l'arrivée de la biblio
   sur AnarBib ; (b) booléen explicite `imported_from_legacy` posé à l'attribution ;
   (c) inférence « identité présente sans entrée de validation AnarBib ». **Reco :
   marqueur explicite** (fiable, exportable). **Décision à acter.**
5. **Attribution ≠ validation.** Éditer l'identité d'un·e `pending_validation` doit être
   permis **sans** valider (ne débloque pas la circulation). Et éditer l'identité d'un·e
   **déjà actif·ve** ne doit pas re-déclencher le flux de validation. → garder les deux
   orthogonaux ; N4 se déclenche sur **attribution**, `validation_confirmed` sur
   **validation** : **dé-dupliquer** quand les deux coïncident.
6. **Réutilisation après `removed`.** L'index unique inclut les lignes `removed`
   (l'identité y reste). Une personne qui **revient** et à qui le staff veut **redonner
   son ancienne identité** → **collision** avec sa propre appartenance retirée.
   **Décision** : à la sortie, **NULL-er** l'identité (libère, perd la trace côté
   membership mais le `membership_validation_log` garde l'historique) **ou** réactiver
   **la même** ligne d'appartenance plutôt qu'en créer une neuve **ou** exclure
   `removed/terminated` de l'index unique. **À trancher.**
7. **Collision à la saisie.** Identité déjà prise dans la biblio → violation d'unicité.
   UX : « cette identité existe déjà dans cette biblio » **sans** révéler de qui
   (confidentialité).
8. **Confidentialité du roster.** Contient e-mail + UUID + identité → **sensible**.
   Export **staff/coordenador de CETTE biblio uniquement** (RLS/`p_library_id`) ; un·e
   coordenador de A ne doit jamais exporter le roster de B. Filtres : inclure ou non les
   `restricted` / `removed` / `pending_validation`.
9. **i18n (10 locales + charte inclusive).** Tout nouveau libellé (champ, hint de
   recherche, erreur de collision, colonnes du roster, corps des e-mails) × **10 locales**
   (DOC-I18N-1), forme neutre/inclusive par langue. Renommer le sens « numéro » →
   « identité/identifiant » dans les libellés (le `readerNumberLabel` existant reste
   utilisable mais son **texte** doit devenir neutre).
10. **Suppression dure d'une appartenance.** `membership_validation_log` est en
    `ON DELETE CASCADE` → un hard-delete perdrait l'historique d'identité. Les
    appartenances sont **soft-removed** (`status='removed'`), donc le log persiste —
    **ne pas introduire** de hard-delete sur ce chemin.

## 9. Décisions à arbitrer (hypothèses + reco — à porter au REGISTRE)

> ✅ **ARBITRÉ (11/06/2026)** — ce bloc a été **inscrit au REGISTRE §27 `CARD-LOCAL`**
> (12 décisions actées). **La source de vérité est désormais le REGISTRE §27** ; le
> texte ci-dessous est conservé comme trace de l'arbitrage et ne fait plus foi.

> Bloc prêt à inscrire au REGISTRE (nouvelle section **§27 `CARD-LOCAL`**) **après
> arbitrage**. Statuts honnêtes : ✅ = déjà vrai/acté aujourd'hui ; 🟡 = à trancher.

| ID proposé | Énoncé | Reco | Statut |
|---|---|---|---|
| **CARD-LOCAL-IDENT** | `local_reader_number` porte une **identité locale** (numéro, **nom** ou autre) — extension de MULTI-E.2 ; libellés UI neutres. | adopter | ✅ (Xavier 10/06) |
| **CARD-LOCAL-STAFF** | L'identité locale est **toujours** un acte **staff** ; le lecteur ne se l'attribue jamais (wizard/e-mails informent seulement). | adopter | ✅ (Xavier 10/06) |
| **CARD-LOCAL-GATE** | L'identité locale **n'est pas** une condition de circulation ; le gate reste sur l'appartenance validée (clarifie MULTI-F.1). | adopter | ✅ (clarification) |
| **CARD-LOCAL-1** | Recherche painel par identité locale **scopée à la biblio courante** ; repli « toutes mes biblios » si zéro résultat, avec biblio d'origine du match. | contexte courant + repli | 🟡 |
| **CARD-LOCAL-2** | **Modèle d'identité par biblio** (N5) : `{numéro libre · numéro séquencé · nom · autre}`, **guide non bloquant** + cache « dernier attribué ». | libre v1 ; séquence optionnelle plus tard | 🟡 |
| **CARD-LOCAL-3** | **Mode de validation par biblio** : présentielle / à distance / aucune — pilote le message création. | ajouter le champ | 🟡 |
| **CARD-LOCAL-4** | Unicité par biblio (index MULTI-E.2 en place) ; message de collision **sans divulgation**. | acté unicité ; UX à écrire | ✅ unicité / 🟡 UX |
| **CARD-LOCAL-5** | **Legacy vs AnarBib** : marqueur **explicite** sur l'appartenance, exporté dans le roster. | marqueur explicite | 🟡 |
| **CARD-LOCAL-6** | **Réutilisation d'identité après `removed`** : NULL à la sortie **ou** réactivation de la même appartenance **ou** index unique limité aux statuts actifs. | à trancher | 🟡 |
| **CARD-LOCAL-N3** | Roster **onglet Rapports** : NOM, prénom, inscrit·e depuis, e-mail, UUID, identité, statut (+ optionnels) ; legacy/AnarBib ; export staff/coordenador, scopé biblio. | adopter | 🟡 |
| **CARD-LOCAL-N4** | Notif réconciliation à l'**attribution** : lectrice **+ biblio** ; dé-dupliquer avec `validation_confirmed` ; via `notify-event`. | adopter | 🟡 (déploiement tributaire Woodpecker) |
| **CARD-LOCAL-CANAL** | Matrice §6 : UUID + login + « comment marche ta biblio » + « tu es en attente » à la **création** ; identité à la **validation/attribution**. | adopter | 🟡 |
| **CARD-LOCAL-I18N** | Tous les messages × **10 locales** (DOC-I18N-1), libellés **neutres** (identité, pas « numéro »). | adopter | 🟡 |

## 10. Dépendances · séquencement · hors-scope

- **Dépendances** : MULTI-E.2 / VALID / gate MULTI-F.1 (✅ en place) ; `notify-event`
  pour N4 (**déploiement bloqué tant que Woodpecker dort**) ; export §12 (réutilisé N3) ;
  lecture de la def **hors-migration** de `fn_painel_find_profile_by_lookup` (préalable N1).
- **Séquencement recommandé** : **N1** (soulagement staff immédiat) → **N2** (attribution)
  → **N5** (modèle biblio + mode validation, qui alimente les messages) → **N3** (roster
  rapports) → **N4** (notifs, dès `notify-event` redéployable) → enfin le **wizard de
  création** (chantier de page à cadrer à part) qui consomme N5 + la matrice §6.
- **Hors-scope (pour l'instant)** : séquences/formats auto par biblio (évolution de N5) ;
  **import de masse** des registres papier (chantier séparé, lié §12) ; unification
  visuelle UUID/identité sur la **carte-lecteur** physique ; refonte du wizard de
  création (à **cadrer/spécifier séparément** — Xavier : « il devient plus que nécessaire
  comme chaque grosse page technique d'AnarBib »).

---
*Fin du cadrage v2. Décisions §9 à arbitrer (réunion/collectif) puis à inscrire au
REGISTRE (§27 `CARD-LOCAL`), une ligne par décision. Le wizard de création fera l'objet
d'un cadrage dédié. Exécution selon §10.*
