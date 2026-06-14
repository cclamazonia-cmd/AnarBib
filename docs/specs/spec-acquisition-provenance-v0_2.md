# Spec — Acquisition & provenance

- **Version :** 0.2 (figée — supersède v0.1)
- **Date :** 2026-06-02
- **Statut :** 🟢 Arbitrages Q1–Q6 + Q3-bis actés. Prêt pour implémentation.
- **Précédence :** cette v0.2 supersède v0.1 (précédence registre > spec courante). Les constats v0.1 EA-ACQ-1 et EA-ACQ-2 sont **corrigés** ci-dessous.
- **Auteur :** Xavier (coordination AnarBib) — cadrage assisté

---

## 0. Correction d'audit (ce que v0.1 disait de faux)

v0.1 reposait sur un audit `information_schema.columns`, **filtré par privilège**, qui
masquait des colonnes. L'audit complet (catalogue `pg_attribute` + corps des RPC +
lecture du front) corrige deux constats :

- **EA-ACQ-2 « mauvais étage » → FAUX.** La provenance est **déjà** au bon étage :
  `exemplares` ET `exemplar_drafts` portent `acquisition_mode`, `acquisition_date`,
  `provenance_note`, `source_library`. La chaîne RPC `attach_exemplar(provenance…) →
  exemplar_drafts → publish_exemplar_draft → exemplares` les propage correctement
  (avec `coalesce` en update).
- **EA-ACQ-1 « capacité latente » → relocalisé.** Le front capture **déjà** la
  provenance d'exemplaire (`ExemplarDraftForm` Step 5 : 4 champs, `handleSave`
  persiste, `handlePublish` propage). Le 0/2719 vient de ce que les 2719 exemplaires
  existants sont issus d'**imports en masse antérieurs**, pas de ce formulaire.

**Conclusion : la fonction acquisition est ~90 % livrée et opérationnelle.** Le vrai
défaut restant n'est pas une absence mais un **double foyer de saisie**.

---

## 1. Le défaut réel : double foyer notice ↔ exemplaire

La provenance est captée **à deux endroits** :

| Champ | Notice (`books`/`book_drafts`, `BookDraftForm`, `fieldRegistry` grp `aquisicao`) | Exemplaire (`exemplares`/`exemplar_drafts`, `ExemplarDraftForm` Step 5) |
| --- | :---: | :---: |
| `acquisition_mode` | ✅ (à retirer) | ✅ source de vérité |
| `acquisition_date` | ✅ (à retirer) | ✅ source de vérité |
| `provenance_note` | ✅ (à retirer) | ✅ source de vérité |
| `source_library` | — | ✅ |
| `source_label`, `owner_library`, `holder_library`, `mutualization_status`, `partner_source`, `source_record_id/url`, `import_format`, `import_method` | ✅ **restent** (Camada 1 / réseau) | — |

Trois champs sont en double : `acquisition_mode`, `acquisition_date`,
`provenance_note`. **Frontière confirmée :** la provenance *physique* appartient à
l'exemplaire (Camada 3) ; ces trois quittent la notice. Tout le reste du groupe
`aquisicao` décrit l'origine de la *notice* / la mutualisation réseau (Camada 1) et
**reste**. Le groupe `aquisicao` (déjà commenté « legacy fiche-level » dans
`fieldRegistry.js`) devient ainsi un groupe purement « origine notice / réseau ».

---

## 2. Périmètre v0.2

**Cœur :**
- **Chantier A — Résolution du double foyer** (front borné + micro-migration de dépréciation).
- **Chantier B — Desiderata** (Q2 : seul vrai chantier neuf).
- **Chantier C — En-tête de provenance du lot** (Q3=Non + Q3-bis a : lots dans le cœur).

**Suites (hors v0.2) :** suggestion d'acquisition côté lecteur·rice ; échange réseau
d'exemplaires (PEB / `mutualization_status` / `library_partnerships`) ; analytics
d'entrées ; objet `reception_event` distinct (écarté par Q3-bis a).

**Hors périmètre, acté :** pas de backfill des 2719 exemplaires legacy — blanc honnête
plutôt que provenance fabriquée (DEC-ACQ-7). Révisable si demande explicite.

---

## 3. Chantier A — Résolution du double foyer

### 3.1 Front (livré en fichiers patchés complets, pas en diffs)

- **`fieldRegistry.js`**, groupe `id: 'aquisicao'` (≈ lignes 339-360, état audit) :
  retirer **3** descripteurs — `acquisition_mode`, `acquisition_date`,
  `provenance_note`. Conserver les 9 autres. Optionnel : renommer le titre
  `catalogacao.ui.acquisitionTitle` → clé « origine notice / rede » (cosmétique, non bloquant).
- **`BookDraftForm.jsx`** : retirer les 3 mêmes champs de
  - l'init d'état (≈ 183-187),
  - le payload `handleSave` (≈ 1597-1609 : `acquisition_mode`, `acquisition_date`, `provenance_note`),
  - `fillFromRecord` (≈ 1800-1812),
  - les générateurs de note ISBD qui les lisent (≈ 1235 `provenance`, 1244 `acquisitionMode`).
  Conserver `owner_library`/`holder_library` (+ `_id`), `mutualization_status`,
  `import_*`, `source_record_*`, `source_label`, `partner_source`.
- **Aucune** modif de `ExemplarDraftForm.jsx` (déjà correct).
- Recon avant patch (doctrine) : `git ls-files | Select-String fieldRegistry` ;
  `Get-Content <path> | Measure-Object -Line` ; vérifier la présence des exports
  attendus avant tout remplacement de fichier vu partiellement.

### 3.2 Migration de dépréciation (pas de DROP)

Un seul fichier `supabase/migrations/<UTC>_acq_deprecate_notice_provenance.sql`
(timestamp **UTC futur**), déployé par `git push` → Woodpecker. **Jamais**
`apply_migration` MCP, **jamais** SQL Editor avant push.

```sql
-- Déprécie la provenance physique au niveau notice (DEC-ACQ-2).
-- Source de vérité = exemplares.* (DEC-ACQ-1). Aucune donnée à migrer (0/2450).
COMMENT ON COLUMN public.books.acquisition_mode  IS 'DEPRECATED v0.2 (DEC-ACQ-2): provenance physique portée par exemplares.acquisition_mode. Ne plus écrire.';
COMMENT ON COLUMN public.books.acquisition_date  IS 'DEPRECATED v0.2 (DEC-ACQ-2): cf. exemplares.acquisition_date.';
COMMENT ON COLUMN public.books.provenance_note   IS 'DEPRECATED v0.2 (DEC-ACQ-2): cf. exemplares.provenance_note.';
COMMENT ON COLUMN public.book_drafts.acquisition_mode IS 'DEPRECATED v0.2 (DEC-ACQ-2): cf. exemplar_drafts.acquisition_mode.';
COMMENT ON COLUMN public.book_drafts.acquisition_date IS 'DEPRECATED v0.2 (DEC-ACQ-2): cf. exemplar_drafts.acquisition_date.';
COMMENT ON COLUMN public.book_drafts.provenance_note  IS 'DEPRECATED v0.2 (DEC-ACQ-2): cf. exemplar_drafts.provenance_note.';

-- Garde-fou : la source de vérité doit exister.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname='exemplares'
      AND a.attname IN ('acquisition_mode','acquisition_date','provenance_note','source_library')
      AND NOT a.attisdropped
    HAVING count(*) = 4
  ) THEN
    RAISE EXCEPTION 'Pré-requis manquant: exemplares.* provenance attendue (DEC-ACQ-1).';
  END IF;
END $$;
```

> Les colonnes notice ne sont **pas** supprimées : réversibilité, et elles servent
> de socle éventuel à un futur pré-remplissage notice → exemplaire (non câblé en v0.2).

---

## 4. Chantier B — Desiderata (Q2)

### 4.1 Table

`supabase/migrations/<UTC>_acq_desiderata.sql` :

```sql
CREATE TABLE public.acquisition_desiderata (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  library_id    uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  status        text NOT NULL DEFAULT 'suggested'
                  CHECK (status IN ('suggested','accepted','acquired','declined')),
  title_hint    text,
  author_hint   text,
  isbn_hint     text,
  linked_book_id bigint REFERENCES public.books(id) ON DELETE SET NULL,
  motivation    text,
  suggested_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  resolved_at   timestamptz,
  resolved_by   uuid REFERENCES auth.users(id) ON DELETE SET NULL
);
CREATE INDEX ON public.acquisition_desiderata (library_id, status);

ALTER TABLE public.acquisition_desiderata ENABLE ROW LEVEL SECURITY;
```

### 4.2 RLS (lecture sous RLS ; écriture par RPC — doctrine v3)

Staff actif de la biblio (Q5). `network_staff` = droits effectifs.

```sql
CREATE POLICY acq_des_select ON public.acquisition_desiderata
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.user_library_memberships m
            WHERE m.user_id = auth.uid() AND m.library_id = acquisition_desiderata.library_id
              AND m.status='active' AND m.role IN ('librarian','coordenador'))
  );
-- INSERT/UPDATE passent par les RPC SECURITY DEFINER ci-dessous (pas de policy write directe).
```

### 4.3 RPC (schéma `api`, `SECURITY DEFINER`, `search_path` figé)

Création d'objets v2 : `REVOKE EXECUTE … FROM PUBLIC, anon, authenticated, service_role`
(une ligne par REVOKE — la regex pre-commit `.+` ne traverse pas les newlines), puis
`GRANT EXECUTE … TO authenticated`.

- `api.create_acquisition_desideratum(p_title_hint text, p_author_hint text, p_isbn_hint text, p_linked_book_id bigint, p_motivation text) RETURNS bigint`
  - résout la biblio primaire active de l'appelant·e ; garde `role IN ('librarian','coordenador')` ;
    insère `status='suggested'`, `suggested_by=auth.uid()`.
- `api.set_acquisition_desideratum_status(p_id bigint, p_status text) RETURNS void`
  - garde le même staff sur la biblio du desideratum ; valide la transition
    (`suggested→accepted|declined`, `accepted→acquired|declined`) ; pose
    `resolved_at/by` sur états terminaux.

Tests RLS en DO bloc : `set_config('request.jwt.claims', …, true)` (pas `SET LOCAL` dans
un DO) + rôle ; `RAISE EXCEPTION` pour rollback. Récupérer le corps via
`pg_get_functiondef(p.oid)` sans troncature.

### 4.4 Front (Catalogação, pas Importações — Q4)

Module léger : liste filtrable par `status` + formulaire de création + puces de statut.
Emplacement : nouvel onglet « Desideratas » dans `CatalogacaoPage`, ou section en tête de
`QueuePanel`. Lecture via `supabase.from('acquisition_desiderata')` (RLS) ; écriture via
les 2 RPC. RBAC bibliothécaire (Q5).

### 4.5 i18n (8 locales — Q6)

Clés `acq.desiderata.*` (titre, champs, statuts, actions) + `acq.mode.<code>` pour les 7
modes (`donation, purchase, exchange, deposit, long_loan, transfer, external_import`).
La base ne porte que `code` ; la traduction vit côté front. Clés plates, LF sans BOM,
2 espaces, **les 8 locales livrées ensemble** (pt-BR, fr, es, en, it, de, ca, eo).

---

## 5. Chantier C — En-tête de provenance du lot (Q3-bis a)

> Valeur réduite depuis l'audit : la saisie **par exemplaire** fonctionne déjà. Le lot
> n'apporte qu'un **pré-remplissage** (saisir la provenance une fois pour un don groupé).
> Maintenu dans le cœur par décision Q3=Non, mais minimal.

### 5.1 Migration — colonnes par défaut sur `catalog_batches`

```sql
ALTER TABLE public.catalog_batches
  ADD COLUMN default_acquisition_mode text,
  ADD COLUMN default_acquisition_date date,
  ADD COLUMN default_source_library  text,
  ADD COLUMN default_provenance_note text;
```

### 5.2 Propagation lot → exemplaire (provenance vide seulement)

`exemplar_drafts.batch_id` existe déjà (aujourd'hui à 0). Règle : quand un brouillon
porte un `batch_id` **et** que son champ de provenance est vide, semer depuis l'en-tête
du lot — **sans écraser** une saisie par copie. Point d'implémentation : au `handleSave`
de `ExemplarDraftForm` (pré-remplissage à l'ouverture si `batch_id`), ou dans
`publish_exemplar_draft` (coalesce draft → batch). Choix : **front au pré-remplissage**
(garde l'exemplaire source de vérité, zéro modif RPC). Front : un sélecteur de lot + un
mini-formulaire d'en-tête de provenance dans le panneau Lotes.

---

## 6. Décisions — entrées REGISTRE prêtes à coller

> À insérer dans `REGISTRE_decisions.md` (source normative). Mettre aussi à jour
> `DOC-I18N-1` (rappel : doit passer de « 8 » à 10 si la cible locales a changé ; ce
> chantier livre les **8** locales actives du front catalogage).

- **DEC-ACQ-1** — La provenance physique (mode, date, source, note) est portée par
  l'**exemplaire** (`exemplares`/`exemplar_drafts`), source de vérité unique (Camada 3). [Q1=A]
- **DEC-ACQ-2** — `acquisition_mode`/`acquisition_date`/`provenance_note` sur
  `books`/`book_drafts` sont **dépréciés** (COMMENT, sans DROP) et retirés des
  formulaires + registre de notice. Restent en Camada 1 : `source_label`,
  `owner_library`, `holder_library`, `mutualization_status`, `partner_source`,
  `source_record_id/url`, `import_format`, `import_method`.
- **DEC-ACQ-3** — Création de `acquisition_desiderata` (library-scoped) ; suggestion
  lecteur·rice reportée en suite. [Q2]
- **DEC-ACQ-4** — Réception traitée par **en-tête de provenance sur `catalog_batches`**
  avec propagation lot → exemplaire à provenance vide ; pas d'objet `reception_event`
  distinct. [Q3=Non + Q3-bis a]
- **DEC-ACQ-5** — Saisie provenance + desiderata = rôle **bibliothécaire local**
  (`librarian`/`coordenador` actif), hors coordination réseau. [Q5]
- **DEC-ACQ-6** — Libellés des modes traduits via clés front `acq.mode.<code>` ; la base
  ne porte que le `code`. [Q6]
- **DEC-ACQ-7** — Pas de backfill des exemplaires legacy : blanc honnête plutôt que
  provenance fabriquée. Révisable sur demande.

---

## 7. Ordre d'exécution (close before open)

1. **A.front** (registre + BookDraftForm) → `npm run build` + `npm test` verts → commit.
2. **A.migration** (COMMENT dépréciation) → fichier UTC → push → Woodpecker.
3. **Vérif bout-en-bout** : cataloguer 1 exemplaire test avec provenance →
   `SELECT acquisition_mode, provenance_note FROM exemplares ORDER BY id DESC LIMIT 1;`
   (lecture MCP) doit montrer la donnée. Confirme la chaîne avant d'ouvrir B.
4. **B** (table + RLS + RPC, puis front, puis i18n 8 locales) — un commit logique par couche.
5. **C** (colonnes lot + pré-remplissage front) — en dernier, valeur de confort.

Chaque paquet : recon (`Select-String`/schéma) → patch → vérif (`Test-Path`/`Select-String`/build) → commit immédiat.

---

## 8. Risques

- **Régression ISBD notice** : si la note ISBD de `BookDraftForm` composait `provenance`/
  `acquisitionMode`, retirer aussi ces lignes (≈ 1235, 1244) sinon clés i18n orphelines.
- **Champs morts bis** : ne pas ajouter les colonnes de lot (C) sans câbler le
  pré-remplissage — sinon on recrée exactement le défaut qu'on corrige.
- **Pre-commit hook** : `REVOKE EXECUTE … FROM PUBLIC` sur une seule ligne par REVOKE ;
  `SECURITY DEFINER` en commentaire ⇒ faux positif, `--no-verify` (backlog #80).
- **Migrations** : timestamps **UTC** ; ne jamais coller le SQL en éditeur avant push
  (sinon « relation already exists » sur Woodpecker).
