# Spec — Carte-lecteur (jeton de présentation)

> **🔵 Clôture (2026-06-10) — implémentée en production, spec archivée.** Phases β + γ livrées. Référence historique (corps non modifié). Preuves : [`AUDIT backlog v29 vs prod`](../../journal/audits/AUDIT_backlog-v29-vs-prod_2026-06-10.md).

> **Statut** : v0.2 du 03/06/2026. Paquet 1 (génération + révocation côté lecteur) **livré en production le 28/05/2026**. Cette version consolide le design en spec opérationnelle et **ajoute le contrat de la RPC de résolution staff** — le morceau différé que le commentaire de table notait « Résolution via RPC staff (Paquet 3, hors bêta) ».
>
> **Lignée** : dossier d'ouverture `CHANTIER_extension_mobile_mode_terrain_2026-05-26` (états 1→3 du concept de carte, § 3). Cette spec en est la décantation opérationnelle.
>
> **Doctrines** : DOC-RPC-3 (RPC pour actions DB) · DOC-OBJ-2 (REVOKE objets backend) · DOC-DEPLOY-1 (migration → Woodpecker) · DOC-PERIM-1 (page = périmètre) · DOC-COLLECTIVE-1 (l'arbitrage A.1 relève de la roadmap collective).
>
> **Hors périmètre v0.2** : l'UI de scan caméra (dépend du socle PWA — Paquet 0 — et du scanner — Paquet 2), la permanence mobile complète (Paquet 3 du chantier : prêt/retour au comptoir mobile), et l'arbitrage **A.1** (séquençage vis-à-vis de Catalogação / échéance Bologne).

---

## 1. Objectif politique

La carte-lecteur **n'est pas une carte d'identité**. C'est une **projection de l'appartenance** (`user_library_memberships`, tout rôle confondu — un·e bibliothécaire emprunte aussi) en un **jeton de présentation opaque**. Elle ne porte rien d'humainement lisible : seulement le **logo / slug de la bibliothèque** et un QR. Hors scan staff, elle est **inerte** — le jeton est un **pointeur, pas une clé**. Trouvée au sol, elle ne révèle ni qui la porte ni un accès au compte. Sa **génération reste un choix du lecteur** : un·e lecteur·rice très exposé·e peut ne jamais en générer et fonctionner à l'identification nominale.

---

## 2. Modèle de menace & propriétés de sécurité

| Propriété | Mécanisme |
|-|-|
| Pas un document d'identité | Aucun nom ni identifiant en clair sur la carte ; logo/slug seulement |
| Inerte hors scan staff | Le QR encode un jeton **opaque** ; il ne résout qu'à travers une RPC réservée au staff de la **bonne** bibliothèque |
| Ne donne pas accès au compte | Le jeton **identifie**, il n'**authentifie** pas ; ce n'est pas une clé de session |
| Révocable | `status` active/revoked ; **un seul actif par appartenance** ; historique des révocations conservé |
| Clair jamais stocké | Seul le `token_hash` (SHA-256) est en base ; le clair n'existe qu'au moment de la génération, côté client |
| Génération = choix | Risque résiduel « carte-fichier sur téléphone saisi » (révèle l'appartenance à *cette* biblio) **acté et documenté** (A.4) ; le·la lecteur·rice décide |

---

## 3. Arbitrages (état au 03/06/2026)

Le dossier de chantier listait **4 arbitrages en attente** ; l'implémentation du 28/05 en a **tranché 3 de facto** (le dossier est antérieur à la livraison).

| Réf | Sujet | Décision |
|-|-|-|
| **A.2** | Portée du jeton | **Par appartenance** : un·e lecteur·rice membre de 3 bibliothèques a 3 cartes. Cohérent avec DOC-PERIM-1 et le fait que la carte porte le logo d'**une** biblio. Garanti par l'index `uq_reader_card_active_per_membership`. ✅ tranché (implémentation 28/05) |
| **A.3** | Stockage du jeton | **Mini-table dédiée** `reader_card_tokens` (conserve l'historique des révocations), plutôt que colonnes jeton/statut sur l'appartenance. Privilégie la traçabilité. ✅ tranché |
| **A.4** | Risque carte-fichier | La carte-fichier sur téléphone saisi réduit fortement le risque sans l'annuler (révèle l'appartenance). **Génération = choix du lecteur.** ✅ acté/documenté |
| **A.1** | Séquençage vs Catalogação | Tout le chantier mobile après Catalogação, **ou** détachement de P0/P1 en avance de phase pour **Bologne (FICEDL sept. 2026)**. P1 est déjà détaché et livré. **🟡 ouvert** — décision de roadmap (cf. DOC-COLLECTIVE-1), conditionne l'ampleur du reste (scanner, permanence). |

---

## 4. Modèle de données

`public.reader_card_tokens` (chantier mobile, 28/05) :

| Colonne | Type | Note |
|-|-|-|
| `id` | uuid PK | `gen_random_uuid()` |
| `membership_id` | uuid NOT NULL | → `user_library_memberships` |
| `user_id` | uuid NOT NULL | porteur du jeton |
| `library_id` | uuid NOT NULL | bibliothèque de l'appartenance |
| `token_hash` | text NOT NULL | **SHA-256** du pointeur opaque (`fn_hash_claim_token`) |
| `status` | text NOT NULL | `active` \| `revoked` (CHECK) |
| `created_at` | timestamptz NOT NULL | `now()` |
| `revoked_at` | timestamptz | renseigné à la révocation |
| `revoked_reason` | text | `regenerated` \| `user_revoked` (extensible) |

Index :
- `uq_reader_card_active_per_membership` — UNIQUE `(membership_id)` **WHERE status='active'** → **un seul jeton actif par appartenance** (A.2).
- `idx_reader_card_tokens_hash` — `(token_hash)` **WHERE status='active'** → lookup rapide à la résolution.
- `idx_reader_card_tokens_user` — `(user_id)`.

Hachage : `public.fn_hash_claim_token(p_token text)` = `encode(digest(p_token,'sha256'),'hex')` (IMMUTABLE STRICT). **Le clair n'est jamais stocké** ; il transite uniquement à la génération (retour de la RPC) et au scan (entrée de la résolution).

---

## 5. Contrats RPC

Toutes les RPC vivent dans le schéma `api`, **SECURITY DEFINER**, search_path figé, REVOKE doctrinal + GRANT ciblé (DOC-OBJ-2).

### 5.1 `api.generate_my_reader_card(p_library_id uuid)` → jsonb ✅ livré (P1)

Le·la membre actif·ve (tout rôle) génère/régénère **sa** carte pour la bibliothèque donnée.
- Garde : `auth.uid()` non nul ; appartenance `active` à `p_library_id` ; `libraries.reader_cards_enabled = true`.
- Effet : **révoque** le jeton actif précédent (`revoked_reason='regenerated'`), génère un jeton clair (`encode(gen_random_bytes(20),'hex')`, 40 hex), insère son `token_hash`.
- Retour : `{ ok:true, token, token_id, library_slug }` — le **clair** n'est rendu qu'ici.
- Refus : `not_authenticated`, `not_a_member`, `cards_disabled`.

### 5.2 `api.revoke_my_reader_card(p_token_id uuid)` → jsonb ✅ livré (P1)

Le·la lecteur·rice révoque **son propre** jeton actif.
- Garde : `auth.uid()` non nul ; jeton trouvé ; `user_id = auth.uid()` (owner) ; jeton encore `active`.
- Effet : `status='revoked'`, `revoked_at=now()`, `revoked_reason='user_revoked'`.
- Retour : `{ ok:true, token_id }`.
- Refus : `not_authenticated`, `not_found`, `not_owner`, `already_revoked`.

### 5.3 `api.resolve_reader_card(p_token text)` → jsonb 🔨 v0.2 (à construire)

Le **staff** scanne (ou saisit) le jeton → résout vers l'appartenance + l'identité du·de la lecteur·rice, pour les opérations de comptoir.

- **Hachage & lookup** : `fn_hash_claim_token(lower(btrim(p_token)))` cherché parmi les jetons `active` (index partiel `idx_reader_card_tokens_hash`).
- **Autorisation interne (le cœur)** : l'appelant·e doit être **staff actif (`librarian` ou `coordenador`) de la bibliothèque du jeton**. La biblio est **dérivée du jeton** (le jeton est déjà scopé — pas de paramètre `library_id`). Si l'appelant·e n'est pas staff de cette biblio → `not_staff_of_library`, **sans divulguer** quoi que ce soit (ni l'existence du jeton ni l'identité).
- **Retour (ok)** : `{ ok:true, reader_user_id, membership_id, library_id, public_id, display_name, is_restricted }` — assez pour identifier au comptoir ; pas d'e-mail (minimisation PII).
- **Refus** : `not_authenticated`, `invalid_token`, `token_not_found`, `not_staff_of_library`.
- **Sécurité** : SECURITY DEFINER (lit `reader_card_tokens` cross-user + le profil d'autrui) ; `REVOKE … FROM PUBLIC, anon, authenticated, service_role` ; `GRANT EXECUTE … TO authenticated` (la garde staff est **interne**).
- **Note privacy** : la résolution **révèle le nom** du·de la lecteur·rice — uniquement au staff de la **bonne** biblio. C'est l'exact pendant de « inerte hors scan staff » : le jeton ne vaut rien hors de ce contexte contrôlé.

---

## 6. Doctrine & déploiement

- **RPC v3 (DOC-RPC-3)** : génération / révocation / résolution = RPC obligatoire (actions DB) ; lectures simples admises via `supabase.from()` sous RLS.
- **Objets backend (DOC-OBJ-2)** : DEFINER + `search_path` figé + `REVOKE FROM PUBLIC, anon, authenticated, service_role` + `GRANT` ciblé + bloc `DO` de vérification en fin de migration.
- **Déploiement (DOC-DEPLOY-1)** : migration SQL horodatée (UTC) → `git push` → Woodpecker (`db push`). `NOTIFY pgrst, 'reload schema'` en fin de migration (la RPC est exposée par PostgREST sur le schéma `api`).

---

## 7. Suite (hors v0.2)

- **UI staff de résolution** : la saisie **manuelle** du jeton est possible sans caméra (un champ + appel `resolve`). Le **scan caméra** requiert le socle PWA (Paquet 0) + le scanner (Paquet 2 : `getUserMedia` + bibliothèque de décodage / `BarcodeDetector`).
- **Permanence mobile (Paquet 3 du chantier)** : opérations de comptoir (prêt/retour/consulta) sur mobile, après P0 + P2.
- **Arbitrage A.1** : à trancher (roadmap, échéance Bologne) — conditionne le séquençage du scanner et de la permanence.

---

## Changelog

- **v0.2 (03/06/2026)** : spec opérationnelle créée depuis le dossier d'ouverture du chantier ; arbitrages A.2 / A.3 / A.4 actés (tranchés par l'implémentation du 28/05) ; **contrat `api.resolve_reader_card` ajouté** (résolution staff). Modèle de données et contrats `generate` / `revoke` alignés sur l'état réel du backend.
- **v0.1** : design dans le dossier d'ouverture `CHANTIER_extension_mobile_mode_terrain_2026-05-26` (états 1→3 du concept).
