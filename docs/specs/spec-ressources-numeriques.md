---
Genre : référence
Statut : 🟢 implémenté (consolidation a posteriori, 19/06/2026) — documente du code en production sans nouvelle décision
Décisions : consolide CAT-B3 (vocabulaire de visibilité), DOC-I18N-1 (locales) ; voisine de `spec-flux-partage-numerique` (ILL-digital, circuit DISTINCT)
Supersédé par : —
---

# spec-ressources-numeriques

| | |
|---|---|
| **Version** | v1.0 — **consolidation a posteriori** (code livré, doctrine de référence écrite le 19/06/2026) |
| **Date** | 19 juin 2026 |
| **Emplacement cible** | `docs/specs/` |
| **Statut** | 🟢 **Implémenté & déployé**. Table `book_digital_resources`, RPC `get_*_digital_asset_*_v2` + `fn_book_restricted_pdf_state_for_current_user` + `fn_confirm_digital_asset_rights`, EF `read-digital-asset` + `read-pdf`, front `ReaderPage` (`/lector`) + viewers (`AudioPlayer`/`VideoPlayer`/`ImageViewer`/`EpubReader` + pdf.js vendored). |
| **Réfère à** | catalogação (`visibility`, `CAT-B3`) · `spec-fiche-publique-bibliotheque` (visibility_level biblio) · chantier lecteur ePub (`epubEngine`). |
| **Dépendances** | Supabase Storage (buckets privés, URL signées) · `book_holdings` / `libraries.visibility_level` (gating d'accès) · `user_library_memberships` (compte actif). |

> **Convention.** Cette spec **décrit l'existant** (consolidation) ; elle n'ouvre **aucun arbitrage doctrinal**. Les points réellement ouverts sont isolés au §10. Toute reformulation de RPC/EF citée ici doit **préserver** le contrat décrit (notamment le gating d'accès §4 et la garde de confirmation des droits §7).
>
> **Distinction liminaire — deux objets à ne pas confondre :**
> - **CE document = les ressources numériques *d'une notice*** : le ou les fichiers (PDF, audio, vidéo, image, ePub, lien externe) attachés à un livre du catalogue, lus *dans* AnarBib par n'importe quel·le usager·e autorisé·e.
> - **`spec-flux-partage-numerique` = le partage *inter-biblios*** (ILL-digital) : circulation d'un scan d'une biblio A vers une biblio B sous *plafond de diffusion*, **circuit distinct** (droit d'un partenariat). Ce n'est PAS le même domaine.

---

## 1. Préambule & objet

- Une **ressource numérique** est un média rattaché à une **notice** (`books`) et **détenu par une bibliothèque**, consultable en ligne dans AnarBib sans quitter l'application.
- Le modèle est **polymorphe** : un même mécanisme (table + RPC + EF + viewers) sert le PDF, l'audio, la vidéo, l'image, l'ePub et le lien externe — la logique « PDF-only » historique a été remplacée par un **point d'entrée unique** (EF `read-digital-asset`).
- Deux finalités structurantes : **(a)** donner accès à des fonds libres de droits ou diffusables ; **(b)** ne jamais transformer un accès de lecture en distribution de copie (anti-copie *by design*, §6 ; circuit de partage tracé séparément, cf. `spec-flux-partage-numerique`).

## 2. Périmètre

**Dans le périmètre :** le modèle de données des ressources d'une notice ; le contrôle d'accès `publico` / `conta_ativa` croisé à la visibilité de la biblio détentrice ; les chemins de lecture (URL signée à TTL court, proxy PDF restreint) ; le rendu front et l'anti-copie ; le cycle des droits (`rights_status`).

**Hors périmètre :** le **partage inter-biblios** (→ `spec-flux-partage-numerique`, plafond de diffusion `ILL-3`) ; l'**export de fonds** (cadrage `CADRAGE_export_fonds_numeriques`) ; le **versement** d'un fichier au catalogage (saisie/upload côté painel) ; le moteur ePub interne (`epubEngine`, chantier dédié).

## 3. Modèle de données — `public.book_digital_resources`

Une ligne = une ressource d'une notice. Colonnes structurantes (telles qu'exposées par les RPC) :

| Colonne | Rôle |
|---|---|
| `id` (bigint) | Identifiant de la ressource (= `asset_id` côté RPC/EF). |
| `book_id` (bigint) | Notice rattachée (`books`). |
| `resource_type` (text) | Type : `pdf_publico`, `pdf_restrito`, `audio`, `video`, `image`, `epub`, `link_externo`. |
| `usage_type` (text) | Finalité d'usage (ex. `leitura_online`). |
| `access_scope` (text) | **Portée d'accès** : `publico` (tout le monde, selon visibilité biblio) ou `conta_ativa` (compte actif requis). |
| `mime_type` (text) | Type MIME (sert à inférer le `viewer_kind`). |
| `storage_bucket` / `storage_path` (text) | Emplacement dans Supabase Storage (**bucket privé** → URL signée). |
| `source_url` (text) | Alternative au stockage : ressource externe (`link_externo`). |
| `source_name`, `attribution_text` | Provenance + attribution (affichées au lecteur). |
| `language_code` (text) | Langue du document. |
| `rights_status` (text) | État des droits : `to_review` → `public_domain_confirmed` (cf. §7). |
| `label` (text) | Libellé affiché. |
| `is_primary` (bool) | Ressource principale de la notice (priorisée à l'affichage). |
| `is_active` (bool) · `status` (text=`active`) | Garde de publication (une ressource doit être active). |
| `bibliographic_match_validated` (bool) | La ressource est bien rattachée à la BONNE notice (garde anti-mauvais-rattachement). |

> **Invariants de publication** (cf. corps des RPC) : une ressource n'est servie que si `is_active = true` **ET** `status = 'active'` **ET** `bibliographic_match_validated = true`. Une ressource `publico` exige en plus que la biblio détentrice soit visible pour l'appelant·e (§4).

## 4. Contrôle d'accès — `access_scope` × visibilité de la biblio détentrice

L'accès se décide en **deux étages** (SECURITY DEFINER, `search_path` fixé) :

1. **Portée de la ressource** (`access_scope`)
   - `publico` : exposée à tout le monde (y compris anon), **sous réserve** de l'étage 2.
   - `conta_ativa` : exige un **compte actif** (`user_library_memberships.status = 'active'`) — RPC « accessible ».

2. **Visibilité de la bibliothèque détentrice** (`libraries.visibility_level` via `book_holdings`)
   - `public` : visible de tout le monde.
   - `network` : visible des **membres actifs** du réseau (non-anon + au moins une adhésion active).
   - `private` : visible des **membres actifs de CETTE biblio** uniquement.

Une ressource n'est servie que si **les deux étages** passent. Conséquence importante : **on ne peut pas fuiter une ressource d'une biblio `network`/`private` au public** via l'asset — la visibilité de la notice détentrice gouverne (cohérent avec la doctrine catalogue, cf. [[catalogue-anon-mv-publique]]).

**RPC du domaine :**

| RPC | Entrée | Rôle | Exécution |
|---|---|---|---|
| `get_book_primary_public_digital_asset_v2(book_id)` | notice | Ressource **principale `publico`** d'un livre. | **anon** (filtrage `access_scope` interne). |
| `get_book_primary_accessible_digital_asset_v2(book_id)` | notice | Ressource principale `publico` **ou** `conta_ativa` selon l'usager·e. | authentifié·e. |
| `get_accessible_digital_asset_by_id_v2(asset_id)` | ressource | Une ressource précise, publiée et accessible (public/conta_ativa). | appelée **avec le jeton de l'usager·e** (identité respectée). |
| `fn_book_restricted_pdf_state_for_current_user(bib_ref)` | réf. notice | Décide la visibilité du **bouton « Ler »** et l'accès au **proxy fermé** (book_exists / has_reading_resource / resource_status / file_exists / user_account_active / can_show_read_button). | authentifié·e + service_role. |

## 5. Chemins de lecture (Edge Functions)

### 5.1 `read-digital-asset` — point d'entrée générique (tous types)
- Entrée : `asset_id`. Appelle `get_accessible_digital_asset_by_id_v2` **avec le jeton de l'appelant·e** (l'accès est donc gardé par le gating §4, pas par la clé service).
- Sortie : métadonnées de la ressource **+** un mode d'accès :
  - `storage_signed` : **URL signée** sur le bucket privé, TTL `DIGITAL_ASSET_SIGNED_URL_TTL_SECONDS` (**défaut 900 s**), générée à la demande (clé service, après le contrôle d'accès) ;
  - `external_url` : pour `link_externo` ;
  - `metadata_only` sinon.
- `viewer_kind` **inféré** (`pdf` / `audio` / `video` / `image` / `epub` / `external_link` / `generic`) à partir de `resource_type` + `mime_type` + extension.
- En-têtes : `cache-control: no-store` (jamais de mise en cache d'un média gardé).

### 5.2 `read-pdf` — proxy PDF restreint (historique, spécialisé)
- Exige un **Bearer token** (401 sinon). Entrée : `bib_ref`.
- S'appuie sur `fn_book_restricted_pdf_state_for_current_user` : ne sert le flux PDF que si les conditions `conta_ativa` sont réunies (compte actif, ressource de lecture présente, fichier existant).
- Sert le PDF **streamé** (jamais d'URL publique), `no-store`.

## 6. Front — `ReaderPage` (`/lector`) & anti-copie

- `ReaderPage` appelle l'EF `read-digital-asset`, puis route vers le viewer selon `viewer_kind` : `AudioPlayer`, `VideoPlayer`, `ImageViewer`, `EpubReader`, ou **pdf.js vendored** (`public/vendor/pdfjs`, chargé en ESM local — pas de CDN).
- **Anti-copie scopé au viewer** (`useViewerCopyProtection`) : interception en *capture phase* de `contextmenu` / `dragstart` / `copy` / `selectstart` + raccourcis (`Ctrl+S/P/A/C/U`, `Ctrl+Shift+I/J/C`, `F12`, `PrintScreen`), **filtrée par containment** (hors viewer, tout reste libre).
- **Honnêteté de conception (doctrine, citée dans le code)** : « *F12 et PrintScreen ne sont pas réellement bloquables dans un navigateur ; ces interceptions sont du décourageant, pas du DRM.* » AnarBib **n'implémente pas de DRM** : la protection réelle des œuvres sous droits passe par le **plafond de diffusion** (partage inter-biblios) et par le fait que **le système ne crée aucune copie persistante** côté client (URL signée éphémère, streaming, pas de téléchargement).

## 7. Droits & provenance — `rights_status`

- Une ressource porte un **état de droits** : `to_review` (par défaut, à examiner) → **`public_domain_confirmed`** (domaine public confirmé).
- La transition est un **acte explicite du coordenador** de la biblio détentrice, via `fn_confirm_digital_asset_rights(asset_id)` (gardée coordenador, idempotente, horodatée `verified_at/by`) : on confirme **après avoir vu la provenance**. Le fichier **reste dans son bucket restreint** ; confirmer les droits ≠ rendre public (la portée publique relève de `access_scope`).
- `source_name` / `source_url` / `attribution_text` accompagnent la ressource et sont affichés au lecteur (attribution = respect des licences libres).

## 8. Sécurité (rappel)

- Toutes les fonctions d'accès sont **SECURITY DEFINER** avec `search_path` fixé, et **gardent l'accès en interne** (étages §4) — l'architecture DEFINER est **intentionnelle** (cf. [[secu-advisors-definer-intentional]]) : `get_book_primary_public_*` est `EXECUTE`-able **anon** par conception (catalogue public), les autres exigent l'identité de l'appelant·e.
- Les fichiers vivent en **bucket privé** ; aucun chemin public direct — toujours une **URL signée éphémère** ou un **streaming proxifié**. `no-store` partout.
- `fn_confirm_digital_asset_rights` : garde **coordenador de la biblio détentrice** (jamais une simple authentification).

## 9. Articulation avec les specs voisines

- **`spec-flux-partage-numerique`** : circuit **distinct**. Ici on *lit* une ressource d'une notice ; là on *transmet* un scan d'une biblio à une autre sous plafond. Les deux partagent l'idée « pas de copie persistante / responsabilité tracée » mais ont des tables et des RPC différentes.
- **Catalogação (`CAT-B3`)** : un **seul vocabulaire de visibilité** dans AnarBib (`public` / `staff_only` côté notice ; `publico` / `conta_ativa` côté portée de ressource) — à garder aligné.
- **`spec-fiche-publique-bibliotheque`** : la `visibility_level` de la biblio détentrice (public/network/private) est le **second étage** du gating d'accès aux ressources.

## 10. Points réellement ouverts (dette, hors consolidation)

- **i18n du lecteur** : l'habillage de `ReaderPage`/viewers est minimaliste (peu de clés dédiées) — à étoffer si on veut une expérience pleinement localisée (parité 10 locales).
- **Vocabulaire `usage_type` / `rights_status`** : seuls `leitura_online`, `to_review`, `public_domain_confirmed` sont attestés ici ; recenser exhaustivement les valeurs en base et les documenter (un futur lot d'audit du domaine).
- **ePub** : le moteur `epubEngine` / `EpubReader` a son **chantier dédié** — cette spec ne couvre que son branchement comme `viewer_kind=epub` dans le point d'entrée unique.
- **Audit immuable des accès** : la lecture ne laisse pas (à ce jour) de trace d'audit dédiée par ouverture ; à arbitrer si un besoin de redevabilité l'exige (≠ le partage inter-biblios, lui, trace).

---

*Consolidation a posteriori produite le 19/06/2026 — documente l'état réel du domaine « ressources numériques d'une notice » (code en production), sans modifier le comportement. Méthode : lecture du baseline + EF + front, jamais le label.*
