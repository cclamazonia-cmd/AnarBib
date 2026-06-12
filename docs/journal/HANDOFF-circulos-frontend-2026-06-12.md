# HANDOFF — Page Círculos (face fédération, paquet 2 frontend)

> Rédigé le 2026-06-12 par la session **« Cercles fédéraux — fondations »**.
> **À lire en entier avant d'attaquer le frontend.** Le backend est **déployé en
> prod et vérifié en base**. Cette note rappelle d'abord *pourquoi* on fait cette
> page, puis ce qui est livré et ce qui reste.

## 0. Pourquoi cette page existe — l'intention, rappelée (demande d'ouverture de session)

La demande initiale, mot pour mot : *« réfléchir à l'opportunité de mettre à
disposition des admins réseau d'AnarBib les outils puissants qui ont permis de
mener à bien le nettoyage, la recherche d'infos pour compléter les fiches
documents et autorités, la remise en cohérence entre fiches et l'uniformisation
des rendus — lors des sessions archivées consécutives à l'arrivée de Baqueiro. »*

La réponse retenue : **distribuer cette puissance, mais au palier sûr et de façon
démocratique**, cohérente avec un fonctionnement **horizontal / anti-autoritaire** :

- **Palier 1 — diagnostic (lecture seule), FAIT** : onglet « Rapports » de `rede`
  (paquet RAPPORTS-REDE) — documents incomplets, autorités à compléter, **doublons
  d'autorités (R3b)**, **incohérences auteurs/contributeurs (R4)**. Ça *montre*, ça
  n'agit pas.
- **Palier 2 — la face fédération (CETTE PAGE)** : le lieu où la gouvernance
  *collective* vivra. Pas une console d'admin (ça, c'est `rede`, gardé
  `isNetworkAdmin`) — un **espace fédératif** ouvert à tout membre rattaché.

> ⚠️ **La page Círculos n'est pas un CRUD.** C'est la concrétisation de cette
> intention : démocratiser le pouvoir vers le réseau. Les 4 principes directeurs
> (REGISTRE §FED, non négociables) doivent transparaître dans l'UX :
> **fédéralisme pas hiérarchie** · **consentement pas décompte** · **autonomie
> locale souveraine** · **lancer peu, mais que ça vive**.

**Deux profils d'admins** (précisé explicitement par Xavier) — l'UI doit servir
les deux, parfois dans la même personne :
1. des **personnes au poids politique** dans le mouvement anar (pas forcément
   techniques) → lisibilité, pas de jargon, pas de tableau de bord chiffré ;
2. des **bibliothécaires** (biblioconomie + parfois technique) → exactitude.

**Et la suite (à garder en tête, pas à coder ici)** : les **autorités étant
partagées**, leur modification (a fortiori en masse) sera **gouvernée au niveau
fédéral**, *démocratisée par consentement*, via les outils/prérogatives de cette
face fédération — c'est **FED-O7** (ouvert au REGISTRE), articulation *split* avec
la future `spec-atelier-autorites`, alimentée par les rapports `rede` R3b/R4.
Cette page est donc destinée à héberger, plus tard, bien plus que les cercles.

## 1. Tu es déjà sous WSL — discipline multi-session

Bien : le frontend se fait sous WSL2 (`~/anarbib`, `npm run dev` natif). La session
qui a écrit ceci tournait côté **Windows** (backend via UNC) et **se retire du
chantier círculos** pour ne pas te marcher dessus.

**Mais le clone reste partagé entre sessions actives.** Donc :
- **Stage UNIQUEMENT tes propres fichiers, nommément. Jamais `git add -A`/`git add .`** —
  l'arbre de travail contient des modifs non commitées d'autres sessions (vu
  aujourd'hui : criar-conta touche les 10 `locales/*.json`, que tu vas aussi éditer
  pour l'i18n des cercles → **risque de collision élevé sur les locales**, coordonne).
- `git fetch` + vérifie `ahead/behind` **avant** chaque push ; horodatage UTC exact
  des migrations ; attends le vert Forgejo avant le push suivant.

## 2. Ce qui est LIVRÉ (backend, déployé en prod, vérifié en base)

Deux migrations sur `codeberg/main`, **appliquées** (objets présents en base) :
- `supabase/migrations/20260612075752_paquet_fed1_circles.sql` (paquet FED-1)
- `supabase/migrations/20260612131910_paquet_fed1b_circle_helpers_revoke_anon.sql` (durcissement)

**Modèle de données** : `public.circles`, `circle_memberships`,
`circle_join_requests`, `circle_join_objections` (RLS activée ; lecture selon
visibilité FED-1/FED-7 ; **écriture refusée hors RPC**).

**Lectures — vues `api` (`from()` toléré, security_invoker, GRANT authenticated)** :
- `api.circles_directory_v1` — annuaire des cercles `is_open & ativo` : `id, nature,
  name, description, members_count`. **Membres non nominatifs** (« visibles après
  l'entrée »).
- `api.my_library_circles_v1` — **vue 1ʳᵉ personne** : cercles où une de *mes* biblios
  est `membro`/`pendente` (+ `members_count`, `circle_status`, `is_open`…). Jamais de
  vue d'ensemble du réseau (FED-7).
- `api.circle_members_v1` — membres d'un cercle dont ma biblio est membre.

**Écritures — RPC (`supabase.schema('api').rpc(...)`, SECURITY DEFINER, gardées
coordenador via `user_can_manage_library`)** :
- `fn_circle_create(p_nature, p_name, p_description, p_library_id, p_is_open)` → `uuid`
- `fn_circle_request_join(p_circle_id, p_library_id)` → `uuid` (adhésion `pendente` +
  demande `open`, délai d'objection **14 j**)
- `fn_circle_object(p_request_id, p_library_id, p_reason)` → `text` (`'open'` ou
  `'refused'`). Motivation **≥ 20 car. obligatoire**. **Anti-blackball (FED-O5)** :
  une objection isolée *suspend et ouvre la discussion* ; refus seulement si **2
  biblios distinctes** objectent (ou **1** si cercle ≤ 2 membres).
- `fn_circle_leave(p_circle_id, p_library_id)` → `void`
- `fn_circle_set_dormancy(p_circle_id, p_action)` — `p_action ∈ reativar/adormecer/arquivar`
- `fn_circle_resolve_due()` → `int` (résout les demandes échues ; **idempotente** ;
  déjà planifiée en `pg_cron` quotidien `anarbib-circle-resolve-due-daily @ 3h30`).

**Contrôle d'accès de la page** = **rattachement à une biblio membre** (toute personne
avec `user_library_memberships.status='active'`, leitor inclus), **distinct de
`isNetworkAdmin`** (FED-2). **Voir = tout membre rattaché ; agir = coordenador** (FED-4).

## 3. À FAIRE — paquet 2 (frontend Círculos)

- **Nouvelle page « face fédération »** en nav **entre `biblioteca` et `rede`**, garde
  d'accès propre (rattachement biblio actif, ≠ `isNetworkAdmin`).
- **Onglet Círculos** (cœur) sur la base de la **maquette `anarbib-circulos-preview.html`**
  (cf. spec §3 ; maquettes sous `docs/specs/maquettes/`), **theme-aware** (`var(--brand-*)`) :
  mes cercles (1ʳᵉ personne) + annuaire des cercles ouverts + créer/rejoindre/quitter/
  adresser/cycle de vie (actions = coordenador), adhésion par consentement (afficher
  objections + délai), signal « sem atividade ».
- **Onglet Início** minimal (accueil non chiffré). Assembleias / Gazeta / Carta /
  Entreajuda = **charpentés/renvoyés** (spec §9) — ne pas remplir maintenant.
- **i18n** : toutes les clés selon **`DOC-I18N-1` (10 locales)**, clés plates, LF sans BOM,
  langage inclusif (charte). ⚠️ collision probable avec la session criar-conta sur les
  locales — coordonne le staging.
- Appeler `api.fn_circle_resolve_due()` **au chargement** de la page (lazy) en plus du cron.

**À NE PAS faire ici** :
- **Pas de notifications** : les events `circle.*` (handler EF `notify-event` +
  mail-strings) sont le **sous-paquet 1b non livré** (le dispatcher attend un
  `record_id bigint`, les cercles sont en `uuid`). Ne câble aucune notif pour l'instant.
- `fn_circle_message` n'existe pas encore (part avec 1b).
- Cercle `is_open=false` : `fn_circle_request_join` lève `invite_only` (chemin invitation
  différé) — gère le cas côté UI (masquer « rejoindre » sur les cercles fermés).

## 4. Références
- Spec : `docs/specs/spec-outils-federalistes.md` **v0.2** (design, onglets §3, primitive §5, prompt §11).
- Décisions : **REGISTRE §24 `FED`** (FED-1..7, FED-O4/O5/O6 tranchés, **FED-O7 ouvert**). On cite l'ID, on ne reformule pas.
- Doctrines : `DOC-RPC-3` (RPC-first), `DOC-I18N-1` (10 locales), `DOC-OBJ-2`, `DOC-DEPLOY-1`.
- Backend de référence à imiter pour le style : migrations `…paquetA_network_admin_infrastructure` (gouvernance) et les 2 migrations cercles ci-dessus.

*Fin du handoff. Backend prêt à brancher sur l'UI ; bon courage pour la face fédération.*
