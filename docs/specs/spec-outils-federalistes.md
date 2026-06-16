# 🤝 spec-outils-federalistes — Face fédération & primitive cercle

| Champ | Valeur |
|---|---|
| **Domaine** | Réseau fédératif — **face fédération** (bloc *Ferramentas federalistas*, nav entre `biblioteca` et `rede`) |
| **Version** | v0.2 (12 juin 2026 — passe de fraîcheur + ouverture FED-O7) |
| **Statut** | 🟡 Cadrée, **arbitrages FED-O4/O5/O6 tranchés (04/06)**, non implémentée. Cœur **rempli** : socle + primitive cercle (étapes 1-2 du chantier). Autres onglets **charpentés/renvoyés**. **v0.2 (12/06)** : faits transverses réalignés (i18n → `DOC-I18N-1` ; déploiement → `DOC-DEPLOY-1`, runner non nommé) ; ouverture **FED-O7** (gouvernance des autorités partagées = prérogative fédérale, liée aux rapports `rede` R3b/R4). |
| **Foyer décisions** | **REGISTRE §`FED`** (FED-1..7, FED-O1..O6) — *on cite l'ID, on ne reformule jamais ici.* Raisonnement : `CADRAGE_modele_acces_concentrique_2026-06-04.md`. Cadre politique : `CHANTIER_reseau_federatif_2026-05-25` (trace). |
| **Dépendances entrantes** | `spec-administrateur-reseau-v0.4` (face administration `rede`, cooptation) · `spec-gouvernance-roles` (rôle coordenador, `user_can_manage_library`) · `spec-partenariat-biblios` (FED-7, tissu relationnel) · `spec-cartographie-reseau` (onglet Carte → MAP) |
| **Dépendances sortantes** | À venir : `spec-assembleias` (non créée). **`spec-gazeta-lettre-federation` v0.1 créée (16/06)** → onglet `Gazeta` dissocié : Gazette *pull* (en prod) / Lettre de la fédération *push* opt-in (REGISTRE §29 `GAZ`). Mutualisation de catalogue → chantier **catalogação** + `fn_library_visible_to_caller`. **Gouvernance des autorités partagées** (FED-O7) → `spec-atelier-autorites` (à créer) ; **signal amont** = rapports `rede` R3b/R4 (paquet RAPPORTS-REDE) + mécanisme `CAT-H1` (`merge_author`/`merge_book`). |
| **Préséance** | En cas de conflit : REGISTRE + cette spec + backlog font foi ; CADRAGE/CHANTIER = trace. |

---

## 1. Objet & doctrine

La page `rede` actuelle est une **console d'administration** (gardée `isNetworkAdmin`). Ce n'est pas un lieu fédératif. Cette spec dote AnarBib d'une **seconde page** — la *face fédération* — espace de vie collective de la fédération, accessible à toute personne rattachée à une bibliothèque membre. Les deux faces coexistent sans calcul transversal (cohérent `DOC-PERIM-1`).

Quatre principes directeurs (du chantier, non négociables) :
- **Fédéralisme, pas hiérarchie.** Aucun objet ne crée d'échelon au-dessus des bibliothèques : pas de biblio « mère », pas de cercle « parent », pas d'assemblée contraignante.
- **Le consentement plutôt que le décompte.** Grammaire du consentement (absence d'objection motivée) réutilisant celle de la cooptation des admins réseau.
- **Autonomie locale souveraine.** Aucune décision réseau ne s'impose à une bibliothèque ; une décision d'assemblée est une recommandation.
- **Lancer peu, mais que cela vive.** On séquence par effort d'animation requis.

Le modèle d'accès de l'ensemble est fixé au registre : voir **FED-1** (relocalisation de `círculos` hors `rede`), **FED-3** (deux axes décollés), **FED-4** (voir ≠ agir), **FED-7** (doctrine anti-panoptique).

## 2. État des lieux (base vérifiée le 04/06/2026)

Méthode du projet : nommer l'existant avant de concevoir.

- **Toute la couche fédérative est à créer.** Aucune table cercle / assemblée / gazette n'existe (`SELECT … information_schema` du 04/06).
- `libraries.id` = `uuid` ; `libraries.network_mode` = `text` (`federated` / `isolated`) ; `slug` présent.
- Socle réseau en place : `network_administrators` (audit/cooptation), `network_staff` (droits effectifs), `user_library_memberships`, `library_partnerships`, `catalog_partners`.
- Helpers réutilisables : `public.user_can_manage_library` (« engage la biblio » = coordenador), `public.user_has_library_staff_role` (staff), **`public.fn_library_visible_to_caller`** (visibilité de la *fiche* biblio : `libraries.visibility_level` ∈ public/network/private). **La mutualisation de catalogue est un axe distinct** — `books.mutualization_status` (inerte à ce jour : aucune contrainte, ~tout `NULL`, aucune fonction de filtrage ne le lit) — voir FED-O6.
- **Dette héritée** (chantier §2.4, hors périmètre) : la page `rede` réalise 2 écritures directes (statut d'une demande d'adhésion, activation d'une biblio) à reprendre en RPC. Les objets de cette spec sont **RPC-first dès l'origine** ; ne pas reproduire ce motif.

## 3. Architecture de la face fédération

**Nouvelle page**, contrôle d'accès propre : **rattachement à une bibliothèque membre** (toute personne, quel que soit son rôle — `user_library_memberships.status='active'`), **distinct de `isNetworkAdmin`** (FED-2). Placement nav **entre `biblioteca` et `rede`** (gradation d'échelle : le dedans de ma biblio → ses relations fédératives → l'administration du réseau).

Onglets (maquette validée `anarbib-circulos-preview.html`) :

| Onglet | Contenu | État dans cette spec |
|---|---|---|
| **Início** | Accueil non chiffré : assemblées à venir, dernier bulletin, derniers articles. Porte d'entrée, pas un tableau de bord. | Socle — v0.1 (page nue + accueil minimal) |
| **Círculos** | Mes cercles + annuaire des cercles ouverts. | **v0.1 — cœur (§5)** |
| **Assembleias** | Assemblées réseau et de cercle, filtrables. | Charpenté §9 — renvoyé (étape 5) |
| **Gazeta** | Bulletin de vie + gazette militante. | Charpenté §9 — renvoyé (étapes 3, 6) |
| **Carta** | Carte cartographique et/ou par cercles, respectant la visibilité de chaque biblio. | Renvoyé à `spec-cartographie-reseau` (MAP) |
| **Entreajuda** | Banque d'entraide + mémoire (chartes, comptes rendus). | Charpenté §9 — renvoyé (étapes 4, 7) |

## 4. Modèle d'accès concentrique (rappel normatif)

Source de vérité = **REGISTRE §`FED`**. Pour situer `círculos` :
- **Voir ≠ agir** (**FED-4**) : la lecture de la face fédération est ouverte à tout membre rattaché ; agir engage la biblio.
- `círculos` est la **portée fédérative du coordenador** (**FED-1**), pas un objet d'administration réseau.
- Aucune lecture ne produit de **vue agrégée du tissu relationnel** (**FED-7**) : la page parle depuis *ma* biblio, jamais « le graphe du réseau ».

## 5. La primitive cercle (cœur v0.1)

### 5.1 Définition

**Le `círculo`** (terme tranché — **FED-O4** : `círculo`, seul à couvrir les 4 natures) est une primitive **unique et plate** : une bibliothèque appartient à autant de cercles qu'elle veut, sans qu'aucun cercle soit « parent ». Structure = **graphe, jamais arbre**. Nature **déclarée** (affinitaire / géographique / linguistique / fédération constituée), purement **informative**, n'ouvrant **aucun droit différencié** (chantier §3.2).

### 5.2 Modèle de données cible *(à confirmer en migration ; cf. méthode #PARTNERS)*

**`public.circles`**

| Colonne | Type | Contrainte | Rôle |
|---|---|---|---|
| id | uuid | PK, default `gen_random_uuid()` | identité |
| nature | text | NOT NULL, CHECK ∈ (`afinitario`,`geografico`,`linguistico`,`federacao`) | étiquette déclarée (informative) |
| name | text | NOT NULL | nom propre du cercle (pas i18n — « FICEDL », « Bibliotecas lusófonas ») |
| description | text | NULL | une phrase, langue du cercle |
| status | text | NOT NULL, default `ativo`, CHECK ∈ (`ativo`,`adormecido`,`arquivado`) | cycle de vie (§5.5) |
| is_open | boolean | NOT NULL, default true | apparaît dans l'annuaire des cercles ouverts |
| last_activity_at | timestamptz | NULL | base du signal « sem atividade » (§5.5) |
| created_by | uuid | NULL, FK `profiles(id)` | audit |
| created_at | timestamptz | NOT NULL, default now() | audit |

**`public.circle_memberships`**

| Colonne | Type | Contrainte | Rôle |
|---|---|---|---|
| id | uuid | PK | identité |
| circle_id | uuid | NOT NULL, FK `circles(id)` ON DELETE CASCADE | cercle |
| library_id | uuid | NOT NULL, FK `libraries(id)` ON DELETE CASCADE | bibliothèque membre |
| status | text | NOT NULL, CHECK ∈ (`membro`,`pendente`) | adhésion effective / demande en attente |
| requested_by | uuid | NULL, FK `profiles(id)` | coordenador demandeur (audit) |
| requested_at | timestamptz | NOT NULL, default now() | audit |
| joined_at | timestamptz | NULL | rempli au consentement |

Contraintes : `UNIQUE(circle_id, library_id)` ; RLS activée sur les deux tables (lecture selon visibilité, écriture refusée hors RPC) ; **cercle hors périmètre RLS** des autres objets, à l'unique exception de la mutualisation de catalogue (FED-O6).

### 5.3 Lectures (vues, RLS, `from()` autorisé — DOC-RPC-3)

- `api.circles_directory_v1` — annuaire des cercles `is_open=true` & `status='ativo'` : nom, nature, description, nombre de membres `membro`. **Lisible par tout membre rattaché.** Membres nominatifs **non exposés** dans l'annuaire (« Membros visíveis após a entrada »).
- `api.my_library_circles_v1` — **vue première personne** : les cercles où *ma* biblio est `membro`/`pendente`, avec leurs membres. Scopée à la biblio courante (FED-7 : aucune vue de conjunto).
- `api.circle_members_v1` — membres d'un cercle dont ma biblio est membre.

### 5.4 Actions (RPC-first ; gardées **coordenador** = `user_can_manage_library` — FED-1)

| RPC (schéma `api`) | Effet | Garde |
|---|---|---|
| `fn_circle_create(nature, name, description, library_id, is_open)` | crée le cercle + 1ʳᵉ adhésion (`membro`) de la biblio proposante | coordenador de `library_id` |
| `fn_circle_request_join(circle_id, library_id)` | crée une adhésion `pendente` ; ouvre le consentement (§5.5) ; émet l'event `circle.join_requested` | coordenador |
| `fn_circle_leave(circle_id, library_id)` | retire l'adhésion | coordenador |
| `fn_circle_message(circle_id, body)` | adressage : « escrever ao círculo » → events vers les biblios membres | coordenador d'une biblio membre |
| `fn_circle_set_dormancy(circle_id, action)` | `action ∈ {reativar, adormecer, arquivar}` (§5.5) | coordenador d'une biblio membre |

Hors v0.1 : **mutualisation de catalogue** (`compartilhar catálogo`) — **opt-in par biblio, multi-cercles**, sur un **axe distinct** de la visibilité de fiche (**FED-O6** : future `library_catalog_sharing(library_id, circle_id)` ; `books.mutualization_status` = exception fine par notice ; granularité (i) = tout le fonds moins `local_only` ; filtrage = fonction dédiée → **catalogação**) ; **ajuda mútua / memória** (boutons posés, contenu renvoyé §9).

Objets backend : doctrine **DOC-OBJ-2** (REVOKE `FROM PUBLIC, anon, authenticated, service_role` ; `SECURITY DEFINER` + `search_path` figé ; bloc DO de vérif ; `DROP+CREATE` si signature change). Tests RLS **DOC-RLS-1**. `NOTIFY pgrst, 'reload schema'` en fin de migration.

### 5.5 Adhésion mutuelle & cycle de vie

**Adhésion = accueil par défaut (opt-out)** (**FED-O5**) : le cercle n'ouvrant aucun droit (FED-3), l'adhésion n'est *pas* une cooptation — **le silence vaut consentement**. La biblio proposante crée le cercle et en est le 1ᵉʳ membre ; toute nouvelle biblio passe par `pendente` via `fn_circle_request_join` (coordenador), notifiée aux coordenadores des biblios membres. Pendant un **délai (~14 j, à caler)**, tout coordenador d'une biblio membre peut **objecter** — motivation longue obligatoire, visible aux membres et à la candidate, tracée (la transparence est le garde-fou). Sans objection à l'échéance → `membro`. **Effet d'une objection = anti-blackball (B)** : une objection isolée **suspend et ouvre la discussion** ; elle ne vaut refus que si **une 2ᵉ biblio membre la rejoint** dans le délai (sinon l'adhésion se fait, l'objection restant consignée). Cas du cercle minuscule (1-2 membres) : l'objection d'un membre = une part majeure → elle bloque. Réemploi de la grammaire cooptation (délais, motivation longue, traçabilité) **en régime opt-out** ; tables `circle_join_requests` + `circle_join_objections` (à confirmer en migration). *Cercle `is_open=false` → hors annuaire, adhésion sur invitation (chemin symétrique).*

**Cycle de vie = signal situé** (FED-7), jamais dashboard : un cercle sans activité depuis un seuil affiche, **à ses membres**, le bandeau « sem atividade há N meses » avec `reativar / adormecer / arquivar`. L'archivage est une **proposition soumise au consentement** des membres — le réseau ne dissout jamais un cercle (autonomie). Un cercle archivé n'est jamais supprimé (mémoire).

### 5.6 Accès (synthèse)

| | Voir | Agir |
|---|---|---|
| Annuaire, mes cercles, membres | tout membre rattaché à la biblio | — |
| Créer / rejoindre / quitter / adresser / cycle de vie | — | **coordenador** (`user_can_manage_library`) |

## 6. RPC & sécurité

RPC-first pour toute écriture (**DOC-RPC-3**) ; `supabase.from()` toléré pour les lectures simples sous RLS (vues §5.3) ; `storage.from()` hors périmètre RPC. Objets backend selon **DOC-OBJ-2**. Déploiement : `git push` → CI (**DOC-DEPLOY-1** — foyer du runner, ne pas le nommer ici) ; migrations DDL en fichiers horodatés UTC dans `supabase/migrations/`, **jamais** SQL Editor ni `apply_migration` MCP.

## 7. Notifications

Events militants via l'infrastructure existante (`notify-event`, fan-out par `library_id`), libellés dans `_shared/i18n/mail-strings.ts` (8 locales, `tMail`), **désactivables** individuellement (doctrine gouvernance d'équipe). On notifie **qui n'a pas initié l'action** (**DOC-NOTIF-1**). Events v0.1 : `circle.join_requested`, `circle.join_consented`, `circle.message`, `circle.dormancy_changed`.

## 8. i18n

Toutes les nouvelles clés dans le nombre de locales fixé par **`DOC-I18N-1`** (foyer unique — **ne pas recopier le compte ici** ; **10** au 12/06 : pt-BR, fr, es, it, de, en, ca, eo, nl, el — langage inclusif compris), livrées en une passe, clés plates, LF sans BOM. *(Les traces antérieures disant « six » ou « huit langues » sont périmées : suivre DOC-I18N-1.)* Le **nom** d'un cercle n'est pas i18n (nom propre) ; seuls les **libellés d'interface** le sont. Terme de la primitive = **`círculo`** (FED-O4).

## 9. Périmètre v0.1 vs ultérieur

**Rempli (v0.1)** : socle (page + contrôle d'accès + onglet Início minimal) ; **primitive cercle** (tables, vues, RPC create/join/leave/message/dormancy, annuaire, mes cercles, adhésion par consentement, cycle de vie).

**Charpenté & renvoyé** :
- **Assembleias** (étape 5) — cycle de vie complet réseau/cercle ; régime de vote, mandat → ouverts (chantier §8.2).
- **Gazeta** (étapes 3/6) — bulletin de vie (réemploi de la synthèse hebdomadaire existante) puis gazette éditoriale (réemploi du flux catalogação). → **Dissocié et cadré (16/06) : `spec-gazeta-lettre-federation` v0.1 / REGISTRE §29 `GAZ`** — Gazette *pull* **en prod**, Lettre de la fédération *push* opt-in **à construire** (le « bulletin de vie » = la lettre).
- **Carta** → `spec-cartographie-reseau` (MAP) — respecte la visibilité par biblio (`fn_library_visible_to_caller`) ; réserve sécurité (biblios non localisées).
- **Entreajuda & memória** (étapes 4/7) — banque d'offres/besoins ; archives (chartes de cercle, comptes rendus).
- **Mutualisation de catalogue** (piste lourde) + **circulation inter-bibliothèques portée par le cercle** — chantiers à part entière (FED-O6).
- **Gouvernance des autorités partagées** (fusion / édition démocratisée) — **prérogative fédérale** (**FED-O7**, ouvert). Articulation *split* : le modèle de proposition/fusion + la grammaire de consentement relèvent de `spec-atelier-autorites` (à créer) ; la face fédération **surface** le rituel de décision et y renvoie. Mécanisme bas niveau déjà livré = `CAT-H1` (`merge_author`/`merge_book`, `merge_log`). **Signal amont** : les rapports `rede` **R3b** (doublons d'autorités) & **R4** (incohérences) du **paquet RAPPORTS-REDE** (12/06) pointent déjà « fusion à proposer au cercle fédéral » — ils alimentent, ne décident pas.

## 10. Points ouverts

**Tranchés le 04/06 et inscrits au REGISTRE §`FED`** : **FED-O4** (terme = `círculo` ; label *Ferramentas federalistas*), **FED-O5** (adhésion opt-out + anti-blackball B), **FED-O6** (mutualisation = axe distinct ; opt-in biblio multi-cercles ; granularité (i)).

**Restent ouverts** (au registre) : **FED-O1** (périmètre vue `painel`), **FED-O2** (traçabilité consultations compte), **FED-O3** (sélecteur de biblio si staff multi-biblios), **FED-O7** (gouvernance des autorités partagées = prérogative fédérale ; articulation *split* avec `spec-atelier-autorites` ; signal amont = rapports `rede` R3b/R4 ; à trancher : portée réseau vs cercle, réemploi de la grammaire FED-O5, qui propose / qui objecte, quorum).

À caler lors du remplissage : délai exact d'objection (FED-O5 propose ~14 j) ; seuil du signal de sommeil (§5.5).

Hérités du chantier §8.2 : régime de vote des assemblées ; mandat impératif vs représentatif ; rythme bulletin/gazette **(✅ résolu — REGISTRE §29 `GAZ`, séparation pull/push, 16/06)** ; reprise RPC des 2 écritures directes de `rede` (dette).

## 11. Prompt de reprise

> Spec v0.2 cadrée, validée, **arbitrages FED-O4/O5/O6 tranchés et inscrits au registre (04/06)** ; **FED-O7 ouvert (12/06)** = gouvernance des autorités partagées (renvoi `spec-atelier-autorites`, signal amont rapports `rede` R3b/R4). Prochaine étape = code, un paquet à la fois (DOC-CLOSE-1) : (1) **migration cercles** — tables `circles` + `circle_memberships` (+ `circle_join_requests` / `circle_join_objections` pour FED-O5), RLS, vues `*_v1`, RPC `fn_circle_*` selon DOC-OBJ-2/DOC-RPC-3 ; `git push` → CI (DOC-DEPLOY-1) ; (2) **frontend** face fédération + onglet Círculos sur la base de la maquette `anarbib-circulos-preview.html` (theme-aware `var(--brand-*)`), i18n selon DOC-I18N-1. L'étape 1 du chantier (page + accès + Início) peut précéder ou accompagner la primitive cercle.

---

*Fin de la spec v0.2. Décisions opposables : voir REGISTRE §`FED`. Cette spec décrit le design/comportement ; elle ne tranche pas les décisions, elle les cite.*
