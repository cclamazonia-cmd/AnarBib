# CADRAGE — Notes de lecture partagées sur les œuvres

> **Date** : 2026-08-01 · **Statut** : cadrage — **à valider en assemblée** (réseau et/ou
> par bibliothèque) avant toute implémentation.
> **Origine** : présentation d'AnarBib au CCLA (matin du 2026-08-01). Un·e camarade demande
> s'il est possible d'ajouter « un système de commentaires sur les livres qu'on a lus ».
> **Profil de gouvernance** : arbitré en amont (cf. §3) ; ce document le fige et en déduit
> une proposition technique.

## 0. En une phrase

Un·e lecteur·rice validé·e peut déposer une **note de lecture en texte libre** sur une
**œuvre** ; la note est **visible dans tout le réseau** sous un **pseudonyme**, chaque
bibliothèque **choisit d'activer** la fonction, et la **modération est locale et
a posteriori** (publication directe, masquage sur signalement).

## 1. Besoin & origine

Les bibliothèques du réseau sont des lieux d'**éducation populaire** : mutualiser la
lecture critique — se transmettre des retours, débattre d'un texte, orienter les
prochain·es lecteur·rices — prolonge directement leur mission. La demande vient de la
base (un·e camarade en présentation), pas d'une logique produit.

## 2. Posture & garde-fous doctrine

- **« Notes de lecture », pas « critiques notées ».** Décision cadrante : **aucune note
  chiffrée, aucune étoile**. La note quantitative importe une logique marchande et
  individualiste (moyenne, concours de popularité, hiérarchie des goûts façon
  Goodreads/Amazon) qui cadre mal avec un projet anticapitaliste. Un retour **qualitatif**
  relève au contraire de la **pédagogie libertaire** : appropriation collective d'un texte.
  Même objet technique, intention opposée — et donc usage différent.
- **Vie privée d'abord.** Affichage **sous pseudonyme choisi** : la lecture d'une personne
  n'est jamais liée publiquement à son identité réelle. Cohérent avec la posture RGPD /
  pseudonymisation déjà en place (`fn_pseudonymize_token`, `erasure_log`).
- **Autogestion, pas contrôle descendant.** Modération **a posteriori** (confiance par
  défaut), assurée par le **staff de la bibliothèque d'origine** de la note ; les décisions
  de fond relèvent des **assemblées**. Pas de validation préalable centralisée.
- **Opt-in.** Aucune bibliothèque n'est forcée : la fonction s'**active par bibliothèque**
  (`reading_notes_enabled`). Une biblio qui ne veut pas de ça n'a rien à modérer.
- **Sobriété.** MVP délibérément minimal : pas de fils de discussion (sinon on crée un
  forum à modérer), pas de notifications, pas de note chiffrée.

## 3. Profil de gouvernance retenu

| Décision | Choix |
|---|---|
| Nature | Note de lecture **en texte**, sans note chiffrée |
| Rattachement / visibilité | Niveau **œuvre** (`works`), visible **dans le réseau**, **opt-in par biblio** |
| Qui peut écrire | **Lecteur·rice validé·e** d'une bibliothèque (adhésion active, non restreinte) |
| Identité affichée | **Pseudonyme** choisi par l'auteur·rice |
| Modération | **A posteriori** : publication directe, masquage + signalement |
| Qui modère | Staff de la **bibliothèque d'origine** de la note (admins réseau en filet) |
| Édition / suppression | L'auteur·rice **peut éditer et supprimer** sa propre note |
| RGPD (suppression de compte) | Note **anonymisée et conservée** (lien identité coupé, texte gardé) |

## 4. Périmètre MVP

**Inclus** : écrire / éditer / supprimer sa note ; affichage réseau sous pseudonyme sur la
fiche œuvre ; opt-in par biblio ; signalement par les lecteur·rices ; masquage par le staff
d'origine ; anonymisation à l'effacement du compte ; les 10 locales.

**Exclu (reporté, cf. §6)** : notes chiffrées/étoiles ; réponses / fils de discussion ;
notifications ; badge « a emprunté ce titre » ; modération réseau centralisée.

## 5. Proposition technique

> Esquisse illustrative (noms de colonnes réels, patrons RLS du projet). Le SQL final sera
> écrit en migration lors de l'implémentation, après adoption en assemblée.

### 5.1 Modèle de données

```sql
-- Une note de lecture, rattachée à l'ŒUVRE (partagée entre éditions & bibliothèques).
create table public.book_reading_notes (
  id                bigint generated always as identity primary key,
  work_id           bigint not null references public.works(id) on delete cascade,
  -- auteur : lien coupé (null) à l'anonymisation RGPD ; le pseudonyme (déjà non
  -- identifiant) et le texte restent.
  author_user_id    uuid references auth.users(id) on delete set null,
  author_pseudonym  text not null,
  -- biblio d'origine : contexte de modération + périmètre d'activation (opt-in).
  origin_library_id uuid not null references public.libraries(id),
  body              text not null check (char_length(btrim(body)) between 1 and 4000),
  language          text,                      -- locale de rédaction (affichage tel quel)
  status            text not null default 'published'
                      check (status in ('published','hidden','removed')),
  hidden_reason     text,
  hidden_by         uuid,
  hidden_at         timestamptz,
  edited            boolean not null default false,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  -- une note par œuvre et par auteur·rice (tant que le compte existe) : évite le spam.
  constraint uniq_note_par_oeuvre_auteur unique (work_id, author_user_id)
);

-- Signalement (a posteriori) : anti-spam calqué sur reader_library_messages.
create table public.book_reading_note_reports (
  id               bigint generated always as identity primary key,
  note_id          bigint not null references public.book_reading_notes(id) on delete cascade,
  reporter_user_id uuid not null,
  reason           text,
  created_at       timestamptz not null default now(),
  resolved_at      timestamptz,
  resolved_by      uuid
);

-- Opt-in par bibliothèque (même table que consultation_timezone).
alter table public.library_service_state
  add column reading_notes_enabled boolean not null default false;
```

### 5.2 RLS (esquisse)

- **Lecture** : les notes `published` sont visibles par tout compte authentifié du réseau ;
  les notes `hidden`/`removed` ne le sont que par leur auteur·rice et le staff de la biblio
  d'origine.
- **Écriture** : réservée à un·e **lecteur·rice validé·e** de la biblio d'origine **si**
  cette biblio a activé la fonction ; l'auteur·rice est forcément soi-même.

```sql
alter table public.book_reading_notes enable row level security;

-- lecture réseau des notes publiées
create policy reading_notes_select_published on public.book_reading_notes
  for select to authenticated
  using (status = 'published'
         or author_user_id = auth.uid()
         or public.user_can_act_as_staff_on_library(origin_library_id));

-- écriture : lecteur·rice validé·e d'une biblio qui a activé la fonction
create policy reading_notes_insert_validated on public.book_reading_notes
  for insert to authenticated
  with check (
    author_user_id = auth.uid()
    and exists (select 1 from public.user_library_memberships m
                where m.user_id = auth.uid()
                  and m.library_id = origin_library_id
                  and m.status = 'active' and m.is_restricted = false)
    and exists (select 1 from public.library_service_state s
                where s.library_id = origin_library_id and s.reading_notes_enabled)
  );

-- l'auteur·rice édite / supprime sa propre note
create policy reading_notes_update_own on public.book_reading_notes
  for update to authenticated
  using (author_user_id = auth.uid()) with check (author_user_id = auth.uid());
create policy reading_notes_delete_own on public.book_reading_notes
  for delete to authenticated using (author_user_id = auth.uid());

-- le staff de la biblio d'origine masque / rétablit (modération a posteriori)
create policy reading_notes_moderate_staff on public.book_reading_notes
  for update to authenticated
  using (public.user_can_act_as_staff_on_library(origin_library_id))
  with check (public.user_can_act_as_staff_on_library(origin_library_id));
```

> ⚠️ Contrôle à ajouter (comme ailleurs dans le projet) : un trigger empêchant l'auteur·rice
> de changer `status`/`hidden_*` via sa policy d'édition (réservé au staff), et le staff de
> réécrire le `body` (réservé à l'auteur·rice). Découpage propre des colonnes modifiables.

### 5.3 Cycle de vie & RGPD

- Suppression de compte / demande d'effacement → l'étape s'ajoute au **flux d'effacement
  existant** : `author_user_id := null` (le `on delete set null` le fait déjà en cas de
  hard-delete), trace dans `erasure_log`. Le pseudonyme étant déjà non identifiant, le texte
  reste comme contribution dépersonnalisée. (Option anti-abus : dériver un jeton stable via
  `fn_pseudonymize_token` si on veut garder une continuité anonyme.)
- Masquage staff = `status='hidden'` (réversible) ; suppression par l'auteur·rice = hard
  delete ; retrait par le staff = `status='removed'` (garde une trace de modération).

### 5.4 Surfaces frontend

- **Fiche œuvre** (`BookPage` / page œuvre) : section « Notes de lecture » listant les notes
  `published` de l'œuvre ; encart de rédaction visible seulement pour un·e lecteur·rice
  validé·e d'une biblio ayant activé la fonction.
- **Compte lecteur** (`AccountPage`) : « Mes notes de lecture » — liste, édition, suppression.
- **Painel** : encart de modération (notes signalées de la biblio, masquer/rétablir) + le
  réglage `reading_notes_enabled` dans les paramètres de la biblio.

### 5.5 i18n

Champ `language` stocké, affichage tel quel (pas de traduction auto). Les 10 locales de
l'interface couvrent les libellés (« notes de lecture », « signaler », etc.).

## 6. Reporté (itérations futures, si le besoin émerge à l'usage)

Badge « a emprunté / consulté ce titre » (lien vérifié vers l'historique) ; réponses /
fils ; notifications ; éventuel filtrage par langue ; modération réseau.

## 7. Points à valider en assemblée

1. **Principe** : le réseau veut-il de cette fonction, sous cette forme (notes qualitatives,
   pseudonymes, réseau + opt-in) ?
2. **Modération** : chaque biblio accepte-t-elle de modérer a posteriori les notes de ses
   propres membres ? Qui, concrètement, s'en charge côté staff ?
3. **Activation** : décision d'activer laissée à chaque collectif (assemblée locale) ?
4. **RGPD** : anonymisation-conservation validée (vs suppression totale) ?

## 8. Découpage de mise en œuvre (après adoption)

- **Lot 1 (SQL)** : table `book_reading_notes` + `book_reading_note_reports` + colonne
  `reading_notes_enabled` + RLS + trigger de garde-fou colonnes + intégration au flux
  d'effacement. (Migration fichier + push, conforme doctrine.)
- **Lot 2 (lecteur)** : section fiche œuvre (lecture + rédaction) + « Mes notes » sur le
  compte.
- **Lot 3 (painel)** : réglage d'activation + encart de modération / signalements.
- **Lot 4** : i18n des libellés (10 locales), tests SQL (RLS : validé vs non-validé vs staff).
