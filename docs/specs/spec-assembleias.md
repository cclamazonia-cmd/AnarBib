# 🏛️ spec-assembleias — Assemblée du réseau

| Champ | Valeur |
|---|---|
| **Domaine** | Réseau fédératif — onglet **Assembleias** (face fédération, `spec-outils-federalistes`) |
| **Version** | v0.1 (16 juin 2026) |
| **Statut** | 🟡 Cadrée. Onglet **présentatif EN PROD** (carte d'accueil staff + contenu 10 langues). Backend **non implémenté**. **v0.1 = objet assemblée + dépôt de points à l'ODJ** (la partie entièrement tranchée). Choix de date, quorum, vote, suivi de mandat, ratification asynchrone : **charpentés & renvoyés** (§11) — ils dépendent de points ouverts (liste des zones notamment). |
| **Foyer décisions** | **REGISTRE §`FED`** (à canoniser — les arbitrages du 16/06 sont encore en **trace** dans le cadrage). Raisonnement : `CADRAGE_assembleias_reseau_2026-06-16.md`. |
| **Dépendances entrantes** | `spec-outils-federalistes` (face fédération, onglet `assembleias`, gating staff `STAFF_ONLY_TABS`, visio Jitsi link-out `VITE_JITSI_DOMAIN=vc.autistici.org`) · `spec-administrateur-reseau` (`network_administrators`, facilitation réseau) · `spec-gouvernance-roles` (`user_can_manage_library` = coordenador). |
| **Dépendances sortantes** | v0.2+ : **choix de date** (disponibilité + préférence) ; **quorum** 60% zones ∧ 50% langues (besoin de la **liste canonique des zones/langues-constituantes**) ; **vote/consentement** des décisions de fond + **ratification asynchrone**. |
| **Préséance** | En cas de conflit : REGISTRE (`FED-…`) + cette spec + backlog font foi ; CADRAGE = trace. |

---

## 1. Objet & doctrine

L'onglet **Assembleias** présente déjà (en prod) la **préfiguration** de l'assemblée du réseau. Cette spec ajoute la **première brique backend** : un **objet assemblée** et le **dépôt de points à l'ordre du jour** par les collectifs membres. Doctrine (REGISTRE §`FED`, rappelée par le cadrage) :

- **Le consentement plutôt que le décompte.** Une décision d'assemblée est une **recommandation**, jamais une contrainte imposée à une bibliothèque (autonomie locale souveraine).
- **Fédéralisme, pas hiérarchie.** Aucune assemblée « mère », pas de voix prépondérante.
- **Légitimité = étalement, pas masse.** Quorum par **zones/langues**, jamais par têtes (v0.2).
- **ODJ sans gardien.** Tout collectif membre inscrit un point ; l'assemblée **adopte son ODJ** à l'ouverture ; la facilitation **organise sans supprimer** (cadrage §6bis).

## 2. État des lieux (vérifié le 16/06/2026)

- **Onglet `assembleias`** : `src/pages/federacao/AssembleiasTab.jsx` (présentatif), wiré dans `FederacaoPage.jsx`, **staff-only** (`STAFF_ONLY_TABS`). Carte de promo staff sur l'accueil Início.
- **Visio** : link-out Jitsi (`VisioRoom` retiré), `VITE_JITSI_DOMAIN = vc.autistici.org`. Salle d'AG : `anarbib-assembleia-<uuid>`, ouverte en onglet.
- **Aucune table assemblée n'existe** (à créer).
- Helpers réutilisables : `public.user_can_manage_library` (coordenador — « engage la biblio »), `public.user_has_library_staff_role` (staff), `public.fn_library_visible_to_caller`, table `network_administrators` (facilitation réseau). Socle : `libraries`, `user_library_memberships`.
- Infra notif : `notify-event` (fan-out par `library_id`, libellés `_shared/i18n/mail-strings.ts`).

## 3. Architecture & périmètre v0.1

**Rempli (v0.1)** :
- **Objet assemblée** (`assembleias`) : une instance d'AG, son cycle de vie minimal, ses dates-jalons (convocation J-30 / dépôt J-15 / publication ~J-10 / tenue J-0), sa salle Jitsi, son **type** (`constituinte` / `ordinaria`).
- **Dépôt de points à l'ODJ** (`assembleia_agenda_items`) : tout coordenador d'une biblio membre dépose un point **avant l'échéance** ; après l'échéance → `varia` (cadrage §6bis). **Jamais de suppression** : la facilitation **ordonne / diffère** (statut), pas `DELETE`.
- **Affichage** dans l'onglet : assemblée(s) à venir, ODJ en construction, mon dépôt.

**Charpenté & renvoyé (v0.2+, §11)** : choix de date (disponibilité + préférence) ; calcul de quorum (60/50, besoin liste des zones) ; suivi de mandat ; vote/consentement des décisions ; ratification asynchrone du filet quorum.

## 4. Modèle de données cible (v0.1) *(noms à confirmer en migration)*

**`public.assembleias`**

| Colonne | Type | Contrainte | Rôle |
|---|---|---|---|
| id | uuid | PK, default `gen_random_uuid()` | identité (sert aussi de salle `anarbib-assembleia-<id>`) |
| title | text | NOT NULL | nom propre (« AG du réseau — automne 2026 »), pas i18n |
| kind | text | NOT NULL, CHECK ∈ (`constituinte`,`ordinaria`) | la 1ʳᵉ = quorum allégé (cadrage §6ter) |
| status | text | NOT NULL, default `em_preparacao`, CHECK ∈ (`em_preparacao`,`convocada`,`em_curso`,`encerrada`,`arquivada`) | cycle de vie |
| convocation_at | timestamptz | NULL | jalon J-30 (annonce) |
| agenda_deadline_at | timestamptz | NULL | jalon **J-15** (clôture des dépôts) |
| agenda_published_at | timestamptz | NULL | jalon ~J-10 (ODJ figé/traduit) |
| scheduled_at | timestamptz | NULL | tenue J-0 (UTC ; null tant que la date n'est pas choisie — v0.2) |
| created_by | uuid | NULL, FK `profiles(id)` | audit (facilitation) |
| created_at | timestamptz | NOT NULL, default now() | audit |

**`public.assembleia_agenda_items`**

| Colonne | Type | Contrainte | Rôle |
|---|---|---|---|
| id | uuid | PK | identité |
| assembleia_id | uuid | NOT NULL, FK `assembleias(id)` ON DELETE CASCADE | rattachement |
| title | text | NOT NULL | intitulé du point |
| rationale | text | NULL | motivation (préparation du mandat) |
| proposing_library_id | uuid | NOT NULL, FK `libraries(id)` | le collectif proposant |
| proposed_by | uuid | NULL, FK `profiles(id)` | audit |
| status | text | NOT NULL, default `proposto`, CHECK ∈ (`proposto`,`varia`,`diferido`,`retirado`) | `varia` = déposé après J-15 ; `diferido` = renvoyé par l'AG ; **jamais `DELETE`** (mémoire) |
| display_order | int | NULL | ordre proposé par la facilitation (NULL = ordre de dépôt) |
| created_at | timestamptz | NOT NULL, default now() | horodatage de dépôt (= filtre J-15) |

Contraintes : RLS activée sur les deux tables (lecture = membre rattaché via `fn_library_visible_to_caller` / appartenance réseau ; écriture **refusée hors RPC**). `UNIQUE` souple non imposée (un collectif peut déposer plusieurs points).

## 5. Lectures (vues `api.*_v1`, `from()` toléré — DOC-RPC-3)

- `api.assembleias_v1` — assemblées visibles (membre rattaché) : `id, title, kind, status, convocation_at, agenda_deadline_at, agenda_published_at, scheduled_at`. Triées `created_at desc`.
- `api.assembleia_agenda_v1` — points d'une assemblée visible : `id, assembleia_id, title, rationale, proposing_library_name, status, display_order, created_at`. La **bibliothèque proposante** est exposée par **nom** (transparence — cadrage §6bis), jamais l'utilisateur·rice.

Vues en `security_invoker = true` (doctrine `.githooks`).

## 6. Actions (RPC-first ; schéma `api` ; DOC-OBJ-2 / DOC-RPC-3)

| RPC | Effet | Garde |
|---|---|---|
| `fn_assembleia_create(p_title, p_kind)` | crée une assemblée `em_preparacao` | **facilitation réseau** (`network_administrators`) |
| `fn_assembleia_set_dates(p_id, p_convocation_at, p_agenda_deadline_at, p_agenda_published_at, p_scheduled_at)` | pose/maj les jalons | facilitation réseau |
| `fn_assembleia_set_status(p_id, p_status)` | transitions de cycle de vie | facilitation réseau |
| `fn_assembleia_propose_item(p_assembleia_id, p_library_id, p_title, p_rationale)` | dépose un point ; **`proposto`** si `now() ≤ agenda_deadline_at` (ou deadline NULL), sinon **`varia`** ; émet `assembleia.item_proposed` | **coordenador** de `p_library_id` (`user_can_manage_library`) |
| `fn_assembleia_order_item(p_item_id, p_display_order)` | ordonne (facilitation) | facilitation réseau |
| `fn_assembleia_defer_item(p_item_id)` | passe un point en `diferido` (**jamais `DELETE`**) | facilitation réseau |
| `fn_assembleia_withdraw_item(p_item_id)` | le collectif proposant retire son point (`retirado`) | coordenador de la biblio proposante |

**Pas de gardien d'admission** : `fn_assembleia_propose_item` n'évalue aucun critère d'acceptation — le dépôt inscrit le point. L'adoption de l'ODJ est un acte d'assemblée (hors logiciel en v0.1 : la facilitation ordonne, l'AG adopte en séance).

## 7. RPC & sécurité

Toute écriture en RPC (**DOC-RPC-3**). Objets backend selon **DOC-OBJ-2** : `REVOKE EXECUTE … FROM PUBLIC, anon, authenticated, service_role` puis `GRANT` ciblé ; `SECURITY DEFINER` + `SET search_path` figé ; bloc `DO` de vérification ; `DROP+CREATE` si signature change. RLS testée (**DOC-RLS-1**, `tests/sql/`). `NOTIFY pgrst, 'reload schema'` en fin de migration. Migration DDL en fichier **horodaté UTC exact** (`YYYYMMDDHHMMSS`, **strictement supérieur au max du dossier** — sessions parallèles), `supabase/migrations/`, **jamais** SQL Editor ni MCP. Déploiement = `git push` → CI (**DOC-DEPLOY-1**).

## 8. Notifications

Via `notify-event` (fan-out par `library_id`), libellés `_shared/i18n/mail-strings.ts`, désactivables, on notifie **qui n'a pas initié** (**DOC-NOTIF-1**). Events v0.1 : `assembleia.convocada` (à la convocation, fan-out réseau), `assembleia.item_proposed` (vers la facilitation). Le gros des notifs (rappels J-15/J-10, publication ODJ) = v0.2.

## 9. i18n

Nouvelles clés `federacao.assembleias.*` (formulaire de dépôt, statuts de point, libellés d'assemblée) dans le **nombre de locales fixé par `DOC-I18N-1`** (10 au 16/06), via script `scripts/i18n-add-federacao-*.cjs`, clés plates, LF sans BOM, charte inclusive par langue. Le `title` d'une assemblée et d'un point **n'est pas i18n** (contenu propre, langue de l'autrice).

## 10. Calendrier & règles (rappel — cadrage, REGISTRE §`FED` à venir)

Surfacés/appliqués **progressivement** : le **dépôt J-15** est appliqué dès v0.1 (la RPC bascule en `varia` après `agenda_deadline_at`). **Convocation J-30 / publication ~J-10**, **mandat impératif**, **quorum 60% zones ∧ 50% langues** (dénominateur sur constituantes réelles ; présence = ≥ 1 collectif mandaté ; filet « décisions provisoires » ; **AG constitutive à quorum allégé**) : règles **portées par la facilitation** en v0.1, **outillées en v0.2** (cf. §11).

## 11. Points ouverts (renvoyés en v0.2+)

- **Choix de date** : tables `assembleia_slots` + `assembleia_availability`, recueil disponibilité (`oui`/`non`/`si nécessaire`) + préférence, algorithme de sélection (cadrage §4.4).
- **Quorum** : calcul 60/50 → exige la **liste canonique des zones géographiques et des langues-constituantes** (point ouvert du cadrage).
- **Suivi de mandat** + **vote/consentement** des décisions de fond + **ratification asynchrone** du filet quorum.
- Équivalence décisionnelle présentiel / non-présentiel.

## 12. Périmètre v0.1 vs ultérieur (synthèse)

**v0.1** : `assembleias` + `assembleia_agenda_items`, RLS, vues `*_v1`, RPC `fn_assembleia_*` (create/set_dates/set_status/propose_item/order_item/defer_item/withdraw_item), dépôt avec bascule `varia` à J-15, affichage + formulaire de dépôt dans `AssembleiasTab`, i18n 10 locales, events `convocada`/`item_proposed`. **Ultérieur** : §11.

## 13. Prompt de reprise

> Spec v0.1 cadrée. Onglet présentatif en prod. Coder par paquets (DOC-CLOSE-1) :
> **(P1) migration** — tables `assembleias` + `assembleia_agenda_items`, RLS, vues `api.*_v1` (`security_invoker`), RPC `fn_assembleia_*` selon DOC-OBJ-2/DOC-RPC-3 ; horodatage UTC exact ; `NOTIFY pgrst` ; `git push` → CI (DOC-DEPLOY-1) ; tests RLS `tests/sql/`.
> **(P2) frontend** — dans `AssembleiasTab` : liste des assemblées + ODJ + **formulaire de dépôt** (gardé coordenador via `canAct`), i18n 10 locales (DOC-I18N-1).
> **(P3) events** — `assembleia.convocada` / `assembleia.item_proposed` (notify-event).
> v0.2 = choix de date + quorum (§11).

---

*Fin de la spec v0.1. Décisions opposables : REGISTRE §`FED` (à canoniser). Cette spec décrit le design/comportement ; elle cite les décisions, ne les tranche pas.*
