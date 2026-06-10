# CADRAGE — Unification « partenaire ↔ source d'import »

> Statut : **CADRAGE** (spec, pas d'implémentation). Date : 2026-06-11 (UTC).
> Session : Rigueur de source à l'import. Décision : Xavier.
> Domaine **transverse** (modèle partenariat) → **coordination requise** avec la
> session propriétaire avant toute implémentation.

## 1. Problème

Aujourd'hui, créer une source d'import se fait **ad hoc** dans la page Importações
(« Deposito formato caseiro » → champ « Novo parceiro » + bouton « + » →
`fn_import_register_deposit_source`). Cette source est un **`partner_name` en
texte libre** dans `ingest.partner_catalog_sources`, **déconnecté** du vrai
modèle de partenariat de l'application. Conséquences :

- **Incohérence UX** : on saisit un partenaire à l'import alors qu'un modèle de
  partenaires/relations riche existe déjà ailleurs (Biblioteca → Relações).
- **Pas de provenance reliée** : la source d'import ne pointe sur aucune entité
  partenaire réelle (juste un nom).
- **Pas de contrôle de diffusion/consentement** au niveau partenaire.
- Le « + » est par ailleurs **défaillant** (l'appel RPC pend côté client — bug à
  traiter séparément, mais que cette refonte rend caduc).

## 2. État existant (vérifié en base) — on ne réinvente RIEN

| Table | Rôle | Colonnes clés |
|---|---|---|
| `public.catalog_partners` | **Entité partenaire** (collectif/biblio externe) | `id, slug, display_name, base_url, software_family, country_code, notes, is_active, integration_mode, relationship_status, first_contact_at…` |
| `public.catalog_partners_policy_flags_v2` | Politiques par partenaire | **`import_allowed`**, `compare_allowed`, `mutualize_allowed`, `relationship_rank`, `policy_summary` |
| `public.library_partnerships` | **Relation** biblio ↔ partenaire | `library_id, partner_library_id, partner_catalog_id→catalog_partners, status, proposed/responded/broken…` |
| `public.partnership_rights` | Droits par partenariat | `partnership_id, right_key` (ex. `import`), `granted_at, granted_by` |
| `public.catalog_partner_capabilities` | Capacités techniques | endpoints, probes |
| `ingest.partner_catalog_sources` | **Source d'import** (aujourd'hui isolée) | `partner_name` (texte libre), `source_kind`, `library_id`, `oai_*`, `zotero_*` |

➡️ **L'« autorisation d'import » demandée existe déjà** : c'est `import_allowed`
(policy flag) et/ou un `partnership_rights.right_key = 'import'`. Le travail n'est
pas de la créer, mais de la **rendre saisissable dans Relações** et de la **faire
respecter par l'import**.

## 3. Cible

> Créer le collectif dans **Biblioteca → Relações** (détails max + case « autorise
> l'import » + détection de doublon en base) → il apparaît automatiquement comme
> **source sélectionnable** à l'import, parce qu'il porte le droit `import`.

Le « + » texte-libre de l'import **disparaît**, remplacé par la sélection d'un
partenaire **déjà autorisé**.

## 4. Conception (4 briques)

1. **Créer/sélectionner un partenaire (Relações).** Formulaire riche → insère un
   `catalog_partners` (`display_name`, `slug`, `country_code`, `base_url`,
   `software_family`, `notes`…) + une `library_partnerships` (biblio courante ↔
   partenaire, `status`). Réutilise les RPC existantes du domaine partenariat (à
   identifier — **ne pas dupliquer**).
2. **Case « autorise l'import ».** Cochée → pose le droit : `partnership_rights`
   (`right_key='import'`) et/ou `import_allowed`. C'est la **rigueur de
   provenance au niveau partenaire** (on trace *de qui* on a le droit d'importer).
3. **Détection de doublon (existence en base).** À la saisie du nom/slug,
   rechercher dans `catalog_partners` (+ `libraries`) un partenaire existant
   (normalisation nom/slug) → proposer de **lier à l'existant** plutôt que créer
   un doublon (ex. « CSL Giuseppe Pinelli — Milano » déjà présent).
4. **Dérivation en source d'import.** À l'import, on **liste les partenaires
   autorisés** (`import_allowed`/droit `import`) pour la biblio courante.
   `ingest.partner_catalog_sources` devient une **projection** d'un partenaire
   autorisé : on lui ajoute un lien (`catalog_partner_id`) pour que la provenance
   (déjà propagée jusqu'aux `book_drafts`, cf. inc. A rigueur de source) pointe
   sur l'entité réelle, pas un texte libre.

## 5. Impact UI

- **Biblioteca → Relações** : nouveau formulaire « créer/lier un partenaire »
  (détails + case import + détection doublon). *(Fichier du domaine partenariat —
  une autre session.)*
- **Importações** : le bloc « Deposito formato caseiro » remplace le champ
  « Novo parceiro » + « + » par un **select de partenaires autorisés** (vide →
  lien « gérer mes partenaires dans Relações »). Le wizard `/importacoes/novo`
  (étape Source) suit la même logique.

## 6. Questions ouvertes / coordination

- **Propriété du domaine** : `catalog_partners`, `library_partnerships`,
  `partnership_rights`, `policy_flags_v2` ont été bâtis par **une autre session**.
  → Identifier qui, et **convenir du découpage** (qui fait Relações, qui fait le
  branchement import) avant d'écrire une ligne dans leur domaine.
- **Permissions** : créer un `catalog_partner` est-il coordenador ou
  network-admin ? (Xavier ne pouvait pas créer un collectif partenaire → à
  élucider : flow manquant, ou gardé admin-réseau ?)
- **`import_allowed` vs `partnership_rights('import')`** : trancher la **source de
  vérité** unique du droit d'import (éviter deux mécanismes divergents).
- **Lien `catalog_partner_id` sur `ingest.partner_catalog_sources`** : colonne à
  ajouter (migration) pour relier source ↔ partenaire.

## 7. Incréments proposés

- **B1** — Migration : `ingest.partner_catalog_sources.catalog_partner_id` (FK,
  nullable) + dérivation des sources depuis les partenaires autorisés.
- **B2** — Relações : formulaire créer/lier partenaire + case import + détection
  doublon (avec la session propriétaire).
- **B3** — Importações : remplacer « + » par le select de partenaires autorisés
  (page + wizard). Retrait du chemin texte-libre.
- **B4** — Provenance : `book_drafts` porte `catalog_partner_id` (continuité de la
  rigueur de source, inc. A).

---

*Note : pour le test 301 CIRA de cette nuit, on ne dépend pas de cette refonte —
il suffit d'une source d'import « CIRA Marseille » créée (chemin minimal). La
refonte ci-dessus est le cadre propre, à bâtir à tête reposée et en coordination.*
